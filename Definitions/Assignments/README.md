
# Policy Assignments

This chapter describes how **Policy Assignments** are handled by PaC. To learn about how custom Policy and Initiative definitions are managed, see the [Policy Definitions](../Policies/README.md) and [Initiative Definitions](../Initiatives/README.md).

The components required for **creating / updating / deleting Policy assignments and Policy set (initiative) assignments** are the following:

| Component | What is it used for? | Where can it be found? |
|--|--|--|
| **Assignment JSON files** | The assignments JSON file follows the management group hierarchy (optionally including subscriptions and resource groups) and defines all policy and initiative assignments on these scopes. | `Definitions/Assignments` folder |
| **Global Settings File** | The `global-settings.jsonc` file specifies common values for Policy Assignments  |`Definitions` folder |

<br/>[Back to top](#policy-assignments)<br/>

## Assignment File Overview Diagram

Assignment files are hierarchical for efficient JSON definitions, avoiding duplication of JSON with copy/paste.
<br/>

![Assignment File Overview Diagram](../../Docs/Images/PaC-Assignment-Structure.png)

<br/>[Back to top](#policy-assignments)<br/>

## Assignment JSON file structure

`scope` and `notScope` use a `PacAssignmentSelector` to specify which scope to use for different environments and tenants. The value for the `PacAssignmentSelector` is passed to the build script as a parameter. A star matches any `PacAssignmentSelector` specified.

  ```json
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
                "dev": [
                    "Specified scope such as: '/subscriptions/00000000-0000-0000-000000000000"
                ],
                "test": [
                     "Specified scope such as: '/subscriptions/00000000-0000-0000-000000000000"
                ],
                "prod": [
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
                        "prod": [
                            "Desired scope such as: /providers/Microsoft.Management/managementGroups/Contoso-Prod"
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
                        "prod": [
                            "Desired scope such as: /providers/Microsoft.Management/managementGroups/Contoso-NonProd"
                        ]
                    }
                }
            ]
        }
    ]
} 
```

<br/>

## Assignment Node Components

| Key | Description | Rule |
|-----|-------------|------|
| `nodeName` | arbitrary name of the node for usage by the scripts to pinpoint format errors. | Must exist in each node. |
| `managedIdentityLocation` | Selects the Managed Identity location for Policies with `DeployIfnotExists` and `Modify` effects. | Any node: overrides previous setting. |
| `scope` | List of scopes for assignment. | Must exist exactly once in each branch of the tree. |
| `notScope` | List of notScopes. | Cumulative in branch. May not appear at a child node once the scope has been determined. |
| `assignment` | Assignment `name`, `displayName` and `description`. | String values are concatenated in each branch. Assignment `name` lengths are limited to 24. Must exist at least once in every branch. |
| `parameters` | Parameter values for the assignment. Specified parameters not defined in the assigned Policy or Initiative are silently ignored. | Union of all the parameters defined in a branch. Parameters redefined at a child (recursive) node overwrite the parent nodes value. |
| `ignoreBranch` | Ignore the rest of the tee staring at this node. Can be used to define future assignments without deploying the assignments. | Any node: overrides are ignored. |
| `enforcementMode` | Similar to `ignoreBranch`, it deploys the assignment and sets the assignment to `Default` or `DoNotEnforce`. `DoNotEnforce` allows a whatif analysis. | Any node: overrides previous setting |
| `definitionEntry` | Specifies the `policyName` or `initiativeName` for the assignment. The name should not be a fully qualified `id`. `friendlyNameToDocumentIfGuid` is purely used as a comment to make the Json more readable if the name is a GUID. | Must exist exactly once in each branch of the tree. |

<br/>[Back to top](#policy-assignments)<br/>

## Details for `scope` and `notScope` Values

### Using the `PacAssignmentSelector`

The assignment selector determines the array being selected for this run of the script (e.g., `dev`, `test` and, `prod` above). Exact matches to the parameter `PacAssignmentSelector` for `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` select that array for `notScope` and `scope`. A star (`*`) in the assignment or globalSettings.jsonc file  always selects the array independent of the `PacAssignmentSelector`. The star is only useful in single tenant scenarios, except for Resource Group patterns.

### Resource Group patterns in `notScope`

`notScope` also accepts Resource Group name patterns with wild cards. Standard `notScope` definitions require fully qualified paths. This solution can add Resource Groups based on name patterns. The patterns are resolved during deployment. Any Resource Group added after the deployment are not automatically added. You must rerun the deployment pipeline to add new Resource Groups.

### Example Scope Definition

| Scope | Example |
|---|---|
| Management group | `/providers/Microsoft.Management/managementGroups/<managementGroupId>` |
| Subscription | `/subscriptions/<subscriptionId>` |
| Resource Group | `/subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>` |

<br/>[Back to top](#policy-assignments)<br/>

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Scripts](../../Scripts/README.md)**

**[Return to the main page](../../README.md)**
<br/>[Back to top](#policy-assignments)<br/>
