

# Policy Assignments

This chapter describes how **Policy and Initiative Assignments** are handled by the Policy-as-Code framework. To learn about how custom Policy and Initiative definitions are managed, see the **[Definitions](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/Definitions.md)**  section.

The components required for **creating / updating / deleting Policy assignments and Policy set (initiative) assignments** are the following:

| Component | What is it used for? | Where can it be found? |
|--|--|--|
| **Assignment JSON file** | The assignments JSON file follows the management group hierarchy (optionally including subscriptions and resource groups) and defines all policy and initiative assignments on these scopes. | These files are located in the `Assignments` subsection of the 'Definitions' folder. |
| **Configuration scripts** | These scripts are used for creating / updating / deleting Policy and Initiative assignments in Azure. These assignments can be defined with the scope of a Management Group / Subscription / Resource Group. |The `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` analyzes changes in policy, initiative, and assignment files. The  `Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1` script is used to deploy policies, initiatives, and assignments at their desired scope, and the `Show-AzPoliciesInitiativesAssignmentsPlan.ps1` script is used to display a summarized plan of all policy, initiative, and assignment changes before deployments are released.|
| **Deployment Pipeline** | This pipeline is shared with definition deployments and invokes the assignment configuration scripts that assign pre-staged (built-in or custom) policy and initiative definitions to the scopes provided. It is set to be triggered on any changes in the Policies repository. | The pipeline is defined in the *[Pipeline.yml](Pipeline/Pipeline.yml)** file|

## Scenarios

The Policy as Code framework supports the following Policy and Initiative assignment scenarios:

- **Centralized approach**: One centralized team manages all policy and initiative assignments in the Azure organization, at all levels (Management Group, Subscription, Resource Group).
- **Distributed approach**: Multiple teams can also manage policy and initiative assignments in a distributed manner if there's a parallel set Management Group hierarchies defined. In this case individual teams can have their own top level Management group (and corresponding Management Groups hierarchy with Subscriptions and Resource Groups below), but assignments must not be made on the Tenant Root Group level.
  > **NOTE**: Distributed teams must only include those scopes in their version of the assignments.json that is not covered by another team.
- **Mixed approach**: A centralized team manages policy and initiative assignments to a certain level (top-down approach), e.g. on the Tenant Root Group level, and top level Management group, and all assignments on lower levels (i.e. lower level Management Groups, Subscriptions and Resource Groups) are managed by multiple teams, in a distributed manner.

 **NOTE**: This solution enforces a centralized approach. It is recommended that you follow a centralized approach however, when using the mixed approach, scopes that will not be managed by the central team should be excluded from the assignments JSON file - therefore the assignment configuration script will ignore these scopes (it won't add/remove/update anything in there). At the same time, the distributed teams must only include those scopes in their version of the assignments.json that is not covered by the central team.

## Assignment File Overview Diagram
![image.png](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/Images/AssignmentOverview.PNG)

## Assignment JSON file structure

``` json
{
    "nodeName": "NodeOneName",
    "parameters": {
        "GlobalParameterOne": [
            "TestValue"
        ]
    },
    "children": [
        {
            "nodeName": "ChildNodeName",
            "scope": {
                "PAC-DEV-001": [
                    "Specified scope such as: '/subscriptions/123456-1234-1234-123456789"
                ],
                "PAC-DEV-002": [
                    "Specified scope such as: '/subscriptions/123456-1234-1234-123456789"
                ],
                "PAC-QA": [
                     "Specified scope such as: '/subscriptions/123456-1234-1234-123456789"
                ],
                "PAC-PROD": [
                     "Specified scope such as: /providers/Microsoft.Management/managementGroups/<managementGroupId>"
                ]
            },
            "children": [
                {
                    "nodeName": "nodeName",
                    "assignment": {
                        "name": "Assignment Name",
                        "displayName": "Assignment Display Name",
                        "description": "Assignment Description"
                    },
                    "definitionEntry": {
                        "policyName": "Reference to Initiative or Policy being assigned",
                        "friendlyNameToDocumentIfGuid": "Human friendly name of policy or initiative"
                    },
                    "parameters": {
                        "Local Parameter such as 'Effect'": "Deny"
                    },
                    "children": [
                        {
                            "nodeName": "NodeOne",
                            "assignment": {
                                "name": "AssignmentOne",
                                "displayName": "Display Name",
                                "description": "Description"
                            },
                            "parameters": {
                                "Lowest Level Local Parameter": "Value"
                            }
                        },
                        {
                            "nodeName": "NodeTwo",
                            "assignment": {
                                "name": "AssignmentTwo",
                                "displayName": "Display Name",
                                "description": "Description"
                            },
                            "parameters": {
                                "Lowest Level Local Parameter": "Value"
                            }
                        }
                        
                    ]
                },
                
            ]
        },
        {
            "nodeName": "NodeTwoName",
            "definitionEntry": {
                "policyName": "Reference to Initiative or Policy being assigned",
                "friendlyNameToDocumentIfGuid": "Human friendly name of policy or initiative",
                "roleDefinitionIds": [
                    "Role definitions needed. For example: b24988ac-6180-42a0-ab88-20f7382dd24c"
                ]
            },
            "assignment": {
                "name": "Assignment Name",
                "displayName": "Display Name",
                "description": "Description of assignment"
            },
            "parameters": {
                "Local Parameter such as 'Effect'": "Deny"
            },
            "children": [
                {
                    "nodeName": "NodeOne",
                    "assignment": {
                        "name": "Assignment Name",
                        "displayName": "Assignment Display Name",
                        "description": "Assignment Description"
                    },
                    "parameters": {
                        "Lowest Level Local Parameter": "Value"
                    },
                    "scope": {
                        "PROD": [
                            "Desired scope such as: /providers/Microsoft.Management/managementGroups/12345678901234567890"
                        ]
                    }
                },
                {
                    "nodeName": "NodeTwo",
                    "assignment": {
                        "name": "Assignment Name",
                        "displayName": "Display Name",
                        "description": "Display Name"
                    },
                    "parameters": {
                        "Lowest Level Local Parameter": "Value"
                    },
                    "scope": {
                        "PROD": [
                            "Desired scope such as: /providers/Microsoft.Management/managementGroups/12345678901234567890"
                        ]
                    }
                }
            ]
        }
    ]
} 
```


### Structural rules
- Scopes can be nested, by using the `children` element. Nested scopes have to contain the above listed 4 elements recursively. The schema doesn't constrain any limitations on depth, but Management groups can only be nested up to 6 levels (+ subscription + resource group level) - therefore there's a 'natural' limit of maximum 8 levels.

### Scope and notScope (exclusion) examples
- For more on notScopes, take a look at the `Scripts and configuration files.md` file.
| Scope | Usage | Example |
|--|--|--|
| Management group | `scope` / `notScope` | `/providers/Microsoft.Management/managementGroups/<managementGroupId>` |
| Subscription | `scope` / `notScope` | `/subscriptions/<subscriptionId>` |
| Resource Group | `scope` / `notScope` | `/subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>` |

## Next steps
Read through the rest of the documentation and configure the pipeline to your needs.

- **[Definitions](Definitions.md)**
- **[Pipeline](Pipeline.md)**
- **[Scripts and Configuration Files](ScriptsAndConfigurationFiles.md)**
- **[Quick Start guide](../../#readme.md)**
- **[Operational Scripts](OperationalScripts.md)**

[Return to the main page.](https://github.com/Azure/enterprise-azure-policy-as-code)
