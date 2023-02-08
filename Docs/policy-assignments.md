
# Policy Assignments

**On this page**

* [Assignment tree structure](#assignment-tree-structure)
* [Assignment nodes and rules](#assignment-nodes-and-rules)
* [EPAC environment specific fields](#epac-environment-specific-fields)
* [Example scope definition](#example-scope-definition)
* [Resource Group patterns in `notScope`](#resource-group-patterns-in-notscope)
* [Define Assignment parameters with a CSV file](#define-assignment-parameters-with-a-csv-file)
* [Examples](#examples)
  * [Simple Policy Assignment (Allowed Locations)](#simple-policy-assignment-allowed-locations)
  * [Security-Focused Policy Assignment with JSON parameters](#security-focused-policy-assignment-with-json-parameters)
  * [Security-Focused Policy Assignment with CSV file parameters](#security-focused-policy-assignment-with-csv-file-parameters)
  * [Inverted Policy Assignment (Tag Inheritance and Required Tags)](#inverted-policy-assignment-tag-inheritance-and-required-tags)
  * [Non-Compliance Messages in a Policy Definition Assignment](#non-compliance-messages-in-a-policy-definition-assignment)
  * [Non-Compliance Messages in a Policy Set Definition Assignment](#non-compliance-messages-in-a-policy-set-definition-assignment)
  * [Non-Compliance Messages in a Policy Set Definition Assignment with a `definitionEntryList`](#non-compliance-messages-in-a-policy-set-definition-assignment-with-a-definitionentrylist)
* [Reading List](#reading-list)

<br/>

This chapter describes how **Policy Assignments** are handled by EPAC. To learn about how custom Policy and Policy Set definitions are managed, see the [Policies](policy-definitions.md) and [Policy Set Definitions](policy-set-definitions.md).

## Assignment tree structure

Assignment JSON is hierarchical for efficient definitions, avoiding duplication (copy/paste) of JSON with copy/paste. Each branch of the tree is cumulative.

> **Note:** <br/>
> The tree is not required to be balanced. The number of levels is not restricted; however, anything beyond 3 levels is unnecessary in real scenarios and would be difficult to read and manage.

<br/>

![Assignment File Overview Diagram](Images/PaC-Assignment-Structure.png)

<br/>

## Assignment nodes and rules

| Key | Required | Description | Rule |
|-----|---------|-------------|------|
| `nodeName` | Required | Arbitrary name of the node for usage by the scripts to pinpoint format errors. It has no meaning for Azure. | Must exist in each node. |
| `assignment` | Required: `name`, `displayName` | Assignment `name`, `displayName` and `description`. Assignment `name` lengths are limited to 24 character total. The string values are concatenated in each branch of the tree. |  Must exist at least once in every tree branch. <br/><br/> Concatenated. |
| policyDefinition or policySetDefinition for Assignment | Required <br/> Option 1 or 2 | Specify the `policyName` or `policySetName` for custom definitions or `policyId` and `policySetId` for built-in definitions. The solution still accepts `initiativeName` and `initiativeId` for backward compatibility. <br/><br/> `displayName` improves the readability of the JSON for Policies with a GUID `name` and is not used in deployments.  | Must exist exactly once per tree branch. |
|  | Option 1  <br/> `definitionEntry` | Single definition to be assigned for each leaf node. |  |
|  | Option 2  <br/> `definitionEntryList` | List of definitions to assign at each leaf. Use it for compliance initiatives to simplify the tree by one layer and the number of tree branches. Each entry in the list must contain the fields above. Additionally it must include an `assignment` entry for each list entry; you may specify to append the strings at the end or prepend them with the `append` boolean field. |  |
| `parameters` or <br/>`parameterFile` and `parameterSelector` | Optional <br/> Option A or  B  | Parameter values for the assignment. Specified parameters not defined in the assigned Policy or Initiative are silently ignored to enable the use of `definitionEntryList`. |  |
|  | Option A  <br/> `parameters` | Parameters in JSON format. | Union of parameter names. <br/><br/> Redefined parameters override parent nodes value.  |
|  | Option B  <br/> `parameterFile` and `parameterSelector` | [Efficiently specify the parameters for large Policy Sets or multiple large Policy Sets](#define-assignment-parameters-with-a-csv-file), across multiple target environment categories. | `parameterFile` must exist exactly once per tree branch. <br/><br/> `parameterSelector` must exist exactly once per tree branch. |
| `scope` | Required <br/> *EPAC env specific* | List of scopes for assignment. | Must exist exactly once in each branch. |
| `notScope` | Optional <br/> *EPAC env specific* | List of notScopes. | Cumulative in branch. May not appear at a child node after `scope`. |
| `managedIdentityLocation` | Optional <br/> *EPAC env specific* | Selects the Managed Identity location for Policies with `DeployIfnotExists` and `Modify` effects. | Any node: overrides previous setting. <br/> *Defaults to value from `global-settings.jsonc`*. |
| `additionalRoleAssignments` | Optional <br/> *EPAC env specific* | `roleDefinitionIds` are calculated from the included (direct or indirect via Initiative) Policy definition(s). Fo some Policies, such as DINE `diagnosticsSettings` the monitor destination might be in a different branch of the Management Group tree from the Assignment. This field specifies any roles requiring assignments in such MG branches. The value is an array, each element containing two items: `roleDefinitionId` and `scope` | Union of entries in branch. |
| `nonComplianceMessages` | Optional | Assign a non-compliance message to the assignment, or individual non-compliance messages if the assignment is for an initiative. This value is an array of objects - each containing a message, and in the case of an initiative a policyDefinitionReferenceId. See [this link](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/assignment-structure#non-compliance-messages) for details | Cumulative. <br/><br/> For  `definitionEntry` (option 1 above) it must be placed outside the assignment block. <br/><br/> For `definitionEntryList` (option 2 above) it can be placed in each list entry. |
| `enforcementMode` | Optional | Similar to `ignoreBranch`, it deploys the assignment and sets the assignment to `Default` or `DoNotEnforce`. `DoNotEnforce` allows a what if analysis. | Any node: overrides previous setting |
| `ignoreBranch` | Optional | Ignore the rest of the tree staring at this node. Can be used to define future assignments without deploying the assignments. | Any node: overrides are ignored. |

## EPAC environment specific fields

The `PacAssignmentSelector` passed to the scripts determines which sub-entry in `scope`, `notScope`, `managedIdentityLocation`, and `additionalRoleAssignments` is used. `"*"` matches any EPAC environment and is commonly used for `managedIdentityLocation`.

```json
"scope": {
  "epac-dev": [
    "/providers/Microsoft.Management/managementGroups/Epac-Mg-1",
    "/providers/Microsoft.Management/managementGroups/Epac-Mg-2"
  ],
  "tenant": [
    "/providers/Microsoft.Management/managementGroups/Contoso-Mg-1"
    "/providers/Microsoft.Management/managementGroups/Contoso-Mg-2"
  ]
}

```

## Example scope definition

| Scope | Example |
|-------|---------|
| Management group | `/providers/Microsoft.Management/managementGroups/<managementGroupId>` |
| Subscription | `/subscriptions/<subscriptionId>` |
| Resource Group | `/subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>` |

## Resource Group patterns in `notScope`

`notScope` also accepts Resource Group name patterns with wild cards. Standard `notScope` definitions require fully qualified paths. This solution can add Resource Groups based on name patterns. The patterns are resolved during deployment.

Any Resource Group added after the deployment are not automatically added to the notScope. You must rerun the deployment pipeline to add newly created Resource Groups which match a notScope pattern.

Example with EPAC environment wildcard `"*"`:

```json
    "notScope": {
      "*": [
        "/resourceGroupPatterns/synapseworkspace-managedrg-*",
        "/resourceGroupPatterns/managed-rg-*",
        "/resourceGroupPatterns/databricks-*"
      ]
    }
```

## Define Assignment parameters with a CSV file

Assigning multiple security and compliance initiatives (e.g., Azure Security Benchmark, NIST 800-53 r5, PCI, NIST 800-171, ...) with just JSON parameters becomes very complex fast. Assigning 5 such Initiatives to 4 environment categories, would require 21 nodes with may repeated items, causing the JSON file to ballon to thousands of lines.

Based on development of the documentation feature using spreadsheets as report output, that capability was adapted to use spreadsheets as input to control parameters for different parameters when deploying Assignments. This approach is best for very large Policy Sets such as Azure Security Benchmark, NIST 800-53, etc.

> Smaller Policy Sets should still be handled with JSON parameters.

Start by generating documentation for one or more of those Policy Sets, then modify the effect and parameter columns for each type of environments you will use. in this example header below the infrastructure environments are prod, test, dev, and sandbox used as prefixes to the columns for Effect and Parameters respectively.

```csv
name,referencePath,policyType,category,displayName,description,groupNames,policySets,allowedEffects,prodEffect,testEffect,devEffect,sandboxEffect,prodParameters,testParameters,devParameters,sandboxParameters
```

In the assignment file, you specify `parameterFile`. It must occur exactly once per tree branch and often done in the root node, adjacent to the `definitionEntryList`.

```json
"parameterFile": "security-baseline-parameters.csv",
"definitionEntryList": [
    {
        "policySetName": "1f3afdf9-d0c9-4c3d-847f-89da613e70a8",
        "displayName": "Azure Security Benchmark",
        "assignment": {
            "append": true,
            "name": "asb",
            "displayName": "Azure Security Benchmark",
            "description": "Azure Security Benchmark Initiative. "
        }
    },
    {
        "policySetName": "179d1daa-458f-4e47-8086-2a68d0d6c38f",
        "displayName": "NIST SP 800-53 Rev. 5",
        "assignment": {
            "append": true,
            "name": "nist-800-53-r5",
            "displayName": "NIST SP 800-53 Rev. 5",
            "description": "NIST SP 800-53 Rev. 5 Initiative."
        }
    }
],
```

In the child nodes specifying the scope(s) the node must specified which column prefix to use for selecting the CSV columns with `parameterSelector`. The actual prefix names have no meaning; they only need to match.

```json
{
    "nodeName": "Prod/",
    "assignment": {
        "name": "pr-",
        "displayName": "Prod ",
        "description": "Prod Environment controls enforcement with initiative "
    },
    "parameterSelector": "prod",
    "scope": {
        "epac-dev": [
            "/providers/Microsoft.Management/managementGroups/Epac-Mg-Prod"
        ],
        "tenant": [
            "/providers/Microsoft.Management/managementGroups/Contoso-Prod"
        ]
    }
},
```

## Examples

In many cases a 3-level hierarchy will be sufficient. `Build-DefinitionsFolders.ps1` always creates three levels and than tries to reduce them to two and in some cases to one level. The levels created are:

* Root: `definitionEntry` or `definitionEntryList`
* Children: `parameters`
* Grandchildren: `assignment` and `scope`

In some cases it is advantageous to turn this hierarchy upside-down:

* Root: `definitionEntry` or `definitionEntryList`, `assignment` and `scope`
* Children: `parameters` ([for example tag names](#inverted-policy-assignment-tag-inheritance)) and `assignment`.

Let's construct some examples to clarify the use of assignments.

<br/>

### Simple Policy Assignment (Allowed Locations)

In the simples case an assignment is a single assignment or with no difference in `assignment`, `parameters`, and `definitionEntry` to multiple scopes. In many scenarios "Allowed Locations" is such a simple Assignment. Such Assignments  do child nodes, just the root node.

```jsonc
{
  "nodeName": "/root",
  "definitionEntry": {
    "displayName": "Allowed Locations Initiative",
    "policySetName": "general-allowed-locations-policy-set"
  },
  "assignment": {
    "name": "allowed-locations",
    "displayName": "Allowed Locations",
    "description": "Sets the allowed locations"
  },
  "metadata": {},
  "enforcementMode": "Default",
  "parameters": {
    "AllowedLocations": [
      "centralus",
      "eastus",
      "eastus2",
      "southcentralus"
    ]
  },
  "scope": {
    "epac-dev": [
      "/providers/Microsoft.Management/managementGroups/Epac-Mg-1"
    ],
    "tenant": [
      "/providers/Microsoft.Management/managementGroups/c"
    ]
  }
}
```

* `nodeName` is required for error messages; it's value is immaterial.
* `definitionEntry` specifies that the custom Policy Set `general-allowed-locations-policy-set` from our starter kit. `displayName` has no meaning - it is for readability and in this instance is superfluous.
* `assignment` fields `name`, `displayName` and `description` are used when creating the assignment.
* This assignment has no `metadata`. You don't need an empty collection. EPAC will add `pacOwnerId` and `roles` `metadata`. Do not add them manually.
* enforcementMode is set to default - it is superfluous.
* `parameters` are obvious. Note: you don't add the `value` layer Azure inserts - EPAC takes care of that.
* `scope`:
  * During Policy resource development (called `epac-dev`) the Assignment is deployed to an EPAC development Management Group `Epac-Mg-1`.
  * During Policy prod deployments (`tenant`-wide), it is deployed to the tenant Management Group `Epac-Mg-1`.
* No `notScope` entries are specified.

If we remove the empty and superfluous entries, we arrive at:

```jsonc
{
  "nodeName": "/root",
  "definitionEntry": {
    "policySetName": "general-allowed-locations-policy-set"
  },
  "assignment": {
    "name": "allowed-locations",
    "displayName": "Allowed Locations",
    "description": "Sets the allowed locations"
  },
  "parameters": {
    "AllowedLocations": [
      "centralus",
      "eastus",
      "eastus2",
      "southcentralus"
    ]
  },
  "scope": {
    "epac-dev": [
      "/providers/Microsoft.Management/managementGroups/Epac-Mg-1"
    ],
    "tenant": [
      "/providers/Microsoft.Management/managementGroups/c"
    ]
  }
}
```

### Security-Focused Policy Assignment with JSON parameters

* In the following example we named or root node (`nodeName`) `/security/`. Since it is only used in case of error messages produced by EPAC during planning it's actual value doesn't matter as long as it's unique.
* We use a `definitionEntryList` to create two assignments at every leaf (six assignments total).
* For `assignment` string concatenation we append the strings in the `definitionEntryList` to the strings in the child nodes. You can see this best when you look at the `description` string in the child  nodes. It will form a sentence when concatenated by `append`ing the `definitionEntryList` `assignment` field `description`.
* The `parameters` specified in the children are specific to the IaC environment types and their `scope`. Note: a real assignment would define many more parameters. The set here is abbreviated since the actual set could easily exceed a hundred entries for each of the IaC environments. We'll see in the next example how to simplify large Policy Set parameters with an CSV file.

```jsonc
{
  "nodeName": "/Security/",
  "definitionEntryList": [
    {
      "policySetId": "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8",
      "displayName": "Azure Security Benchmark",
      "assignment": {
        "append": true,
        "name": "asb",
        "displayName": "Azure Security Benchmark",
        "description": "Azure Security Benchmark Initiative."
      }
    },
    {
      "policySetId": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f",
      "displayName": "NIST SP 800-53 Rev. 5",
      "assignment": {
        "append": true,
        "name": "nist-800-53-r5",
        "displayName": "NIST SP 800-53 Rev. 5",
        "description": "NIST SP 800-53 Rev. 5 Initiative."
      }
    }
  ],
  "children": [
    {
      "nodeName": "Prod/",
      "assignment": {
        "name": "pr-",
        "displayName": "Prod ",
        "description": "Prod Environment controls enforcement with "
      },
      "parameters": {
        "classicComputeVMsMonitoringEffect": "Deny",
        "disallowPublicBlobAccessEffect": "deny",
        "azureCosmosDBAccountsShouldHaveFirewallRulesMonitoringEffect": "Deny",
        "allowedContainerImagesInKubernetesClusterEffect": "Audit",
        "AllowedHostNetworkingAndPortsInKubernetesClusterEffect": "Disabled",
        "clusterProtectionLevelInServiceFabricMonitoringEffect": "Deny",
      },
      "scope": {
        "epac-dev": [
          "/providers/Microsoft.Management/managementGroups/epac-dev-prod"
        ],
        "tenant": [
          "/providers/Microsoft.Management/managementGroups/Contoso-Prod"
        ]
      }
    },
    {
      "nodeName": "NonProd/",
      "assignment": {
        "name": "np-",
        "displayName": "NonProd ",
        "description": "Non Prod Environment controls enforcement with "
      },
      "parameters": {
        "classicComputeVMsMonitoringEffect": "Deny",
        "disallowPublicBlobAccessEffect": "deny",
        "azureCosmosDBAccountsShouldHaveFirewallRulesMonitoringEffect": "Audit",
        "allowedContainerImagesInKubernetesClusterEffect": "Audit",
        "AllowedHostNetworkingAndPortsInKubernetesClusterEffect": "Disabled",
        "clusterProtectionLevelInServiceFabricMonitoringEffect": "Audit",
      },
      "scope": {
        "epac-dev": [
          "/providers/Microsoft.Management/managementGroups/epac-dev-nonprod"
        ],
        "tenant": [
          "/providers/Microsoft.Management/managementGroups/Contoso-nonprod"
        ]
      }
    },
    {
      "nodeName": "Sandbox/",
      "assignment": {
        "name": "sbx-",
        "displayName": "Sandbox ",
        "description": "Sandbox Environment controls enforcement with "
      },
      "parameters": {
        "classicStorageAccountsMonitoringEffect": "Deny",
        "allowedServicePortsInKubernetesClusterEffect": "Disabled",
        "certificatesValidityPeriodInMonths": 13,
        "AllowedAppArmorProfilesInKubernetesClusterEffect": "Disabled",
        "certificatesValidityPeriodMonitoringEffect": "disabled",
        "cognitiveServicesAccountsShouldRestrictNetworkAccessMonitoringEffect": "Disabled",
        "AllowedCapabilitiesInKubernetesClusterEffect": "Disabled"
      },
      "scope": {
        "epac-dev": [
          "/providers/Microsoft.Management/managementGroups/epac-dev-sandbox"
        ],
        "tenant": [
          "/providers/Microsoft.Management/managementGroups/Contoso-Sandbox"
        ]
      }
    }
  ]
}
```

### Security-Focused Policy Assignment with CSV file parameters

This example is the same as the previous, except we replaced inline JSON parameters with a CSV file and use the column prefixes in the CSV file to select which parameter values we use by:

* Setting the file name at the root node with

  ```jsonc
  "parameterFile": "security-baseline-parameters.csv",
   ```

* Setting the column prefix with `parameterSelector` to `prod`, `nonprod` and `sandbox`. For example:

  ```jsonc
  "parameterSelector": "prod",
  ```

The CSV file is explained [above](#define-assignment-parameters-with-a-csv-file). The entire file is:

```jsonc
{
  "nodeName": "/Security/",
  "parameterFile": "security-baseline-parameters.csv",
  "definitionEntryList": [
    {
      "policySetId": "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8",
      "displayName": "Azure Security Benchmark",
      "assignment": {
        "append": true,
        "name": "asb",
        "displayName": "Azure Security Benchmark",
        "description": "Azure Security Benchmark Initiative."
      }
    },
    {
      "policySetId": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f",
      "displayName": "NIST SP 800-53 Rev. 5",
      "assignment": {
        "append": true,
        "name": "nist-800-53-r5",
        "displayName": "NIST SP 800-53 Rev. 5",
        "description": "NIST SP 800-53 Rev. 5 Initiative."
      }
    }
  ],
  "children": [
    {
      "nodeName": "Prod/",
      "parameterSelector": "prod",
      "assignment": {
        "name": "pr-",
        "displayName": "Prod ",
        "description": "Prod Environment controls enforcement with "
      },
      "scope": {
        "epac-dev": [
          "/providers/Microsoft.Management/managementGroups/epac-dev-prod"
        ],
        "tenant": [
          "/providers/Microsoft.Management/managementGroups/Contoso-Prod"
        ]
      }
    },
    {
      "nodeName": "NonProd/",
      "parameterSelector": "nonprod",
      "assignment": {
        "name": "np-",
        "displayName": "NonProd ",
        "description": "Non Prod Environment controls enforcement with "
      },
      "scope": {
        "epac-dev": [
          "/providers/Microsoft.Management/managementGroups/epac-dev-nonprod"
        ],
        "tenant": [
          "/providers/Microsoft.Management/managementGroups/Contoso-nonprod"
        ]
      }
    },
    {
      "nodeName": "Sandbox/",
      "parameterSelector": "sandbox",
      "assignment": {
        "name": "sbx-",
        "displayName": "Sandbox ",
        "description": "Sandbox Environment controls enforcement with "
      },
      "scope": {
        "epac-dev": [
          "/providers/Microsoft.Management/managementGroups/epac-dev-sandbox"
        ],
        "tenant": [
          "/providers/Microsoft.Management/managementGroups/Contoso-Sandbox"
        ]
      }
    }
  ]
}
```

### Inverted Policy Assignment (Tag Inheritance and Required Tags)

As mentioned above sometimes it is advantageous (to reduce the number of repetitions) to turn a definition on its head:

* **Common** `parameters`, `scope`, `definitionEntryList` (with two Policies) at the root (`nodeName` is `/Tags/`).
* Start of the `assignment` strings (`append` is defaulted to `false`). Again look at description which will be a concatenated sentence.
* The children define the `tagName` parameter and the second part of the strings for `assignment`.. The set of `parameters` is the union of the root node and the child node.
* This creates six Assignments (number of Policies assigned times number of children).

```jsonc
{
  "nodeName": "/Tags/",
  "parameters": {
    "excludedRG": [
      "synapseworkspace-managedrg-*",
      "databricks-rg-*",
      "managed*"
    ]
  },
  "scope": {
      "epac-dev": [
          "/providers/Microsoft.Management/managementGroups/epac-dev-mg-1"
      ],
      "tenant": [
          "/providers/Microsoft.Management/managementGroups/Contoso-Root"
      ]
  },
  "definitionEntryList": [
      {
          "policyName": "rg-required-tag-dynamic-notscope",
          "assignment": {
              "name": "rgtag-",
              "displayName": "Require Tag on Resource Group - ",
              "description": "Require Tag for Resource Groups when any resource group (not listed in in excludedRg) is created or updated - "
          }
      },
      {
          "policyName": "resources-inherit-rg-tag-dynamic-notscope",
          "assignment": {
              "name": "taginh-",
              "displayName": "Inherit Tag from Resource Group - ",
              "description": "Modify Tag to comply with governance goal of enforcing Tags by inheriting Tags from RG - "
          }
      }
  ],
  "children": [
      {
          "nodeName": "AppName",
          "assignment": {
              "name": "AppName",
              "displayName": "AppName",
              "description": "AppName."
          },
          "parameters": {
              "tagName": "AppName"
          }
      },
      {
          "nodeName": "Environment",
          "assignment": {
              "name": "Environment",
              "displayName": "Environment",
              "description": "Environment."
          },
          "parameters": {
              "tagName": "Environment"
          }
      },
      {
          "nodeName": "Project",
          "assignment": {
              "name": "Project",
              "displayName": "Project",
              "description": "Project."
          },
          "parameters": {
              "tagName": "Project"
          }
      }
  ]
}
```

### Non-Compliance Messages in a Policy Definition Assignment

An example of a policy assignment for a single policy definition with a default non-compliance message.

```jsonc
{
    "nodeName": "test",
    "scope": {
        "issue48": [
            "/providers/Microsoft.Management/managementGroups/issue48"
        ]
    },
    "assignment": {
        "displayName": "Audit virtual machines without disaster recovery configured",
        "description": null,
        "name": "46332f3a51cb4bf2b4de78a7"
    },
    "definitionEntry": {
        "policyName": "0015ea4d-51ff-4ce3-8d8c-f3f8f0179a56" // Single policy definition
    },
    "nonComplianceMessages": [ // Array of nonComplianceMessages
        {
            "Message": "Update non-compliance message" // Default nonComplianceMessage
        }
    ],
    "parameters": {}
}
```

### Non-Compliance Messages in a Policy Set Definition Assignment

An example of a policy assignment for a policy set definition with a default non-compliance message and a policy specific non-compliance message.

```jsonc
{
    "nodeName": "test",
    "scope": {
        "issue48": [
            "/providers/Microsoft.Management/managementGroups/issue48"
        ]
    },
    "assignment": {
        "displayName": "Configure Azure Defender for SQL agents on virtual machines",
        "description": null,
        "name": "39a366e6"
    },
    "definitionEntry": {
        "initiativeName": "39a366e6-fdde-4f41-bbf8-3757f46d1611" // Policy set definition
    },
    "nonComplianceMessages": [ // Array of nonComplianceMessages
        {
            "message": "Update main message" // Default nonComplianceMessage
        },
        {
            "message": "Individual policy message", // Policy specific nonComplianceMessage. You must include the policyDefinitionReferenceId as defined in the initiative.
            "policyDefinitionReferenceId": "ASC_DeployAzureDefenderForSqlAdvancedThreatProtectionWindowsAgent"
        }
    ],
    "parameters": {}
}
```

### Non-Compliance Messages in a Policy Set Definition Assignment with a `definitionEntryList`

An example of how to use a non-compliance message when using a `definitionEntryList` list in the assignment.

```jsonc
{
    "nodeName": "test",
    "scope": {
        "issue48": [
            "/providers/Microsoft.Management/managementGroups/issue48"
        ]
    },
    "definitionEntryList": [
        {
            "initiativeName": "62329546-775b-4a3d-a4cb-eb4bb990d2c0",
            "assignment": {
                "displayName": "Flow logs should be configured and enabled for every network security group",
                "description": "Audit for network security groups to verify if flow logs are configured and if flow log status is enabled. Enabling flow logs allows to log information about IP traffic flowing through network security group. It can be used for optimizing network flows, monitoring throughput, verifying compliance, detecting intrusions and more.",
                "name": "62329546"
            },
            "nonComplianceMessages": [ // nonComplianceMessages must be in the definitionEntryList object for each policy/initiative deployed.
                {
                    "message": "Updated Default message"
                },
                {
                    "message": "Individual policy message",
                    "policyDefinitionReferenceId": "NetworkWatcherFlowLog_Enabled_Audit"
                }
            ]
        },
        {
            "initiativeName": "cb5e1e90-7c33-491c-a15b-24885c915752",
            "assignment": {
                "displayName": "Enable Azure Cosmos DB throughput policy",
                "description": "Enable throughput control for Azure Cosmos DB resources in the specified scope (Management group, Subscription or resource group). Takes max throughput as parameter. Use this policy to help enforce throughput control via the resource provider.",
                "name": "cb5e1e90"
            }
        }
    ],
    "parameters": {
        "throughputMax": 400
    }
}
```

<br/>

## Reading List

* [Setup DevOps Environment](operating-environment.md) .
* [Create a source repository and import the source code](clone-github.md) from this repository.
* [Select the desired state strategy](desired-state-strategy.md)
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.
* Optional: generate a starting point for the `Definitions` folders:
  * [Extract existing Policy resources from an environment](extract-existing-policy-resources.md).
  * [Import Policies from the Cloud Adoption Framework](cloud-adoption-framework.md).
* [Add custom Policies](policy-definitions.md).
* [Add custom Policy Sets](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).
* Import Policies from the [Cloud Adoption Framework](cloud-adoption-framework.md).
* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](operational-scripts.md).

**[Return to the main page](../README.md)**
