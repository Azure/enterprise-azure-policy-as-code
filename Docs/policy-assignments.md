
# Policy Assignments

This chapter describes how **Policy Assignments** are handled by EPAC. To learn about how custom Policy and Policy Set definitions are managed, see the [Policies](policy-definitions.md) and [Policy Set Definitions](policy-set-definitions.md).

## Assignment JSON structure

Assignment JSON is hierarchical for efficient definitions, avoiding duplication (copy/paste) of JSON. Each branch of the tree is cumulative. Each tree node must include a `nodeName` - an arbitrary string exclusively used by EPAC to display an error location. EPAC concatenates a leading `/` and the nodeName entries encountered in the tree to create a "breadcrumbs" trail; therefore, we recommend that you use `/` to help separate the concatenated `nodeName`. The following (partial and invalid) assignment tree would create this error message.

```json
{
  "nodeName": "/Security/",
  "definitionEntry": {
    "policySetName": "org-sec-initiative",
  },
  "children": [
    {
      "nodeName": "Prod/",
      "parameters": {
        "some-effect": "Deny",
      }
    }
  ]
}
```

### JSON Schema

The GitHub repo contains a JSON schema which can be used in tools such as [VS Code](https://code.visualstudio.com/Docs/languages/json#_json-schemas-and-settings) to provide code completion.

To utilize the schema add a ```$schema``` tag to the JSON file.

```
{
  "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json"
}
```

This schema is new in v7.4.x and may not be complete. Please let us know if we missed anything.

### Key Points

* Every tree branch must accumulate a `definitionEntry` (or `definitionEntryList`), Assignment naming (`name` and `displayName`) and `scope` element.
* The elements `parameters`, `overrides`, `resourceSelectors`, `notScope`, `enforcementMode`, `metadata`, `userAssignedIdentity`, `managedIdentityLocations`,`additionalRoleAssignments`and`nonComplianceMessages` are optional.
* For Policy Sets with large numbers of included Policies you should use a spreadsheet (CSV file) to manage **effects** (parameterized or effect `overrides`), `parameters` and optional `nonComplianceMessages`. We recommend the CSV approach for Policy Sets with more than 10 included Policies.
* EPAC continues to support deprecated elements `initiativeId`, `initiativeName` and `ignoreBranch`, Consider using their replacements `policySetId`, `policySetName` and `enforcementMode` instead.

!!! note
    The tree is not required to be balanced. The number of levels is not restricted; however, anything beyond 3 levels is unnecessary in real scenarios and would be difficult to read and manage as the depth increases.

### Tree Structure

![Assignment File Overview Diagram](Images/PaC-Assignment-Structure.png)

## Assignment Naming Element

Each Assignment is required to have a `name` which is used in it's resource id. EPAC also requires a `displayName`. The `description` is optional. For the allowed location assignment you specify the component with:

```json
"assignment": {
    "name": "allowed-locations",
    "displayName": "Allowed Locations",
    "description": "Sets the allowed locations."
},
```

Multiple `assignment` naming components in a tree branch are string concatenated for each of the three fields.

!!! warning
    Azure has a limit of 24 characters for the concatenated `name` string. EPAC displays an error if this limit is exceeded.

## Assigning Policy Sets or Policies

Each assignment assigns either a Policy or Policy Set. In EPAC this is done with a `definitionEntry` or a `definitionEntryList`. Exactly one occurrence must exist in any collated tree branch. For each entry, you need to specify one of the following:

* `policyName` - custom Policy managed by EPAC. Specifying just the name allows EPAC to inject the correct definition scope.
* `policySetName` - custom Policy Set managed by EPAC.
* `policyId` - resource id for builtin Policy.
* `policySetId` - resource id for builtin Policy Set.

`displayName` is an optional field to document the entry if the Policy name is a GUID. Builtin Policies and Policy Sets use a GUID.

```json
"definitionEntry": {
    "policySetName": "general-allowed-locations-policy-set",
    "displayName": "Use this if the Policy name is a GUID"
},
```

Using `definitionEntryList` allows you to save on copy/paste tree branches. Without it, the number of branches would need to be duplicated as many times as the list has entries.

Each entry in the list creates an Assignment at each leave of the tree. Since assignments must have unique names at a specific scope, the Assignment naming component must be amended for each list entry. In this sub-component you can decide if you want to concatenate the string by appending or prepending them by specifying `append` boolean value.

```json
"definitionEntryList": [
    {
        "policySetId": "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8",
        "displayName": "Azure Security Benchmark",
        "assignment": {
            "append": true,
            "name": "asb",
            "displayName": "Azure Security Benchmark",
            "description": "Azure Security Benchmark Initiative. "
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
```

In the above example one of the children (leaf node) has the following Assignment name.

```json
"assignment": {
    "name": "pr-",
    "displayName": "Prod ",
    "description": "Prod Environment controls enforcement with "
},
```

This example generates two assignments at the "prod" leaf per scope:

* /providers/Microsoft.Management/managementGroups/***Contoso-Prod***/providers/Microsoft.Authorization/policyAssignments/**pr-asb**
  * `displayName` = "Prod Azure Security Benchmark"
  * `description` = "Prod Environment controls enforcement with Azure Security Benchmark Initiative."
* /providers/Microsoft.Management/managementGroups/***Contoso-Prod***/providers/Microsoft.Authorization/policyAssignments/**pr-nist-800-53-r5**
  * `displayName` = "Prod NIST SP 800-53 Rev. 5"
  * `description` = "Prod Environment controls enforcement with NIST SP 800-53 Rev. 5 Initiative."

## Assignment scopes and excluded scopes

`scope` is required exactly once in each tree branch. Excluded scopes (`notScope`) are cumulative from `global-settings.json` and the entire tree branch; however, once a scope is defined `notScope` may not be defined at any child node.

Both `scope` and `notScope` are specific to an [EPAC Environment using the pacSelector name](index.md#understanding-epac-environments-and-the-pacselector), e.g., `epac-dev` and `tenant`.

```json
"scope": {
    "epac-dev": [
        "/providers/Microsoft.Management/managementGroups/Epac-Prod"
    ],
    "tenant": [
        "/providers/Microsoft.Management/managementGroups/Contoso-Prod"
        "/providers/Microsoft.Management/managementGroups/Contoso-Prod2"
    ]
}
```

`notScope` works the same. In addition `"*"` means all EPAC Environments which is most often used for `resourceGroupPatterns`.

```json
"notScope": {
    "*": [
        "/resourceGroupPatterns/excluded-rg*"
    ],
    "tenant": [
        "/providers/Microsoft.Management/managementGroups/Epac",
        "/providers/Microsoft.Management/managementGroups/"
    ]
}
```

## Managed Identities and role assignments

Policies with a `DeployIfNotExists` or `Modify` effect need a Managed Identity (MI) and role assignments to execute remediation task. EPAC calculates the necessary role assignments based on the `roleDefinitionIds` in the Policy definition. By default EPAC uses a system-assigned Manged Identity. The team maintaining EPAC recommend system-assigned identities; however, your organization may have role assignment reasons to use user-assigned Managed Identities.

### Defining `managedIdentityLocations`

Policy assignments requiring a Managed Identity (system-assigned or user-assigned) require a location `managedIdentityLocations`. You must specify the location based on EPAC Environment or use `"*"` to use the same location for all of the EPAC Environments.
You can specify them in `global-settings.jsonc` or at any node in the tree. The last (closest to the leaf node) is the one chosen if multiple `managedIdentityLocations` entries are encountered in a tree branch.

```json
"managedIdentityLocations": {
    "*": "eastus2"
},
```

### Defining optional `additionalRoleAssignments`

In some scenarios you will need `additionalRoleAssignments`; e.g., for diagnostics settings to Event Hubs, the target resource might be in a different Management Group and therefore the Managed Identity requires additional role assignments. You must specify the `additionalRoleAssignments` based on EPAC Environment or use `"*"`to use the same `additionalRoleAssignments`for all of the EPAC Environments.

```json
"additionalRoleAssignments": {
    "*": [
        {
            "roleDefinitionId": "/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
            "scope": "/subscriptions/<id>/resourceGroups/<example>"
        }
    ]
},
```

### User-assigned Managed Identities

Azure Policy can use a user-defined Managed Identity and EPAC allows you to use this functionality (new in version 7.0). You must specify the user-defined Managed Identity based on EPAC Environment or use `"*"` to use the same identity for all of the EPAC Environments (only possible in single tenant scenarios). Within each EPAC Environment entry, you can specify just the URI string indicating to use the same identity even if we are using a `definitionEntryList`, or in the case of a `definitionEntryList` can assign a different identity based on the definitionEntryList by specifying a matching `policyName`, `policyId`, `policySetName` or `policySetId`.

```json
"userAssignedIdentity": {
    // For single definitionEntry or when using the same identity for all definitions being assigned
    "tenant1": "/subscriptions/id/resourceGroups/testRG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity-1",
    "tenant2": [
      // differentiate by assigned definition
      {
          "policySetName": "somePolicySetName",
          "identity": "/subscriptions/id/resourceGroups/testRG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity-2"
      },
      {
          "policySetId": "somePolicySetId",
          "identity": "/subscriptions/id/resourceGroups/testRG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/identity-3"
      }
    ]
}
```

!!! note
    The rest (below) of the node components are optional.

## Defining `parameters` with JSON

`parameters` have a simple JSON structure. You do not need the additional `value` indirection Azure requests (EPAC will inject that indirection).

```json
"parameters": {
  "aksClusterContainersAllowedImagesExcludedNamespaces": [
    "kube-system",
    "gatekeeper-system",
    "azure-arc"
  ],
  "kvKeysActiveMaximumNumberOfDays": 90,
  "publicNetworkAccessShouldBeDisabledForContainerRegistriesEffect": "Audit",
  "mysqlDisablePublicNetworkAccessEffect": "Deny",
  "kvRsaCryptographyMinimumKeySizeEffect": "Deny",
},
```

Too enable `definitionEntryList`, parameters not present in the Policy or Policy Set definition are quietly ignored.

## Defining `overrides` with JSON

`overrides` are in the same [format as documented by Azure](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/assignment-structure#overrides-preview). They are  cumulative in each tree branch. The `selectors` element is only used for Assignments of Policy Sets. They are not valid for Assignments of a single Policy.

If using `definitionEntryList`, you must add the `policyName`, `policyId`, `policySetName` or `policySetId` as used in the `definitionEntryList` item.

```json
"overrides": [
    {
        "policySetId": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f",
        "kind": "policyEffect",
        "value": "AuditIfNotExists",
        "selectors": [
            {
                "kind": "policyDefinitionReferenceId",
                "in": [
                    "331e8ea8-378a-410f-a2e5-ae22f38bb0da",
                    "385f5831-96d4-41db-9a3c-cd3af78aaae6"
                ]
            }
        ]
    },
    {
        "policySetId": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f",
        "kind": "policyEffect",
        "value": "AuditIfNotExists",
        "selectors": [
            {
                "kind": "policyDefinitionReferenceId",
                "in": [
                    "cddd188c-4b82-4c48-a19d-ddf74ee66a01",
                    "3cf2ab00-13f1-4d0c-8971-2ac904541a7e"
                ]
            }
        ]
    }
],
```

## Defining `nonComplianceMessages` with JSON

Assign a non-compliance message to the assignment, or individual non-compliance messages if the assignment is for an Policy Set. This value is an array of objects - each containing a message, and in the case of an initiative a policyDefinitionReferenceId. See [this link](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/assignment-structure#non-compliance-messages) for details.

If you use single `definitionEntry`, place them normally. If you use a `definitionEntryList` place them in the respective list entry.

```json
"nonComplianceMessages": [
    {
        "message": "Update main message"
        // Default nonComplianceMessage
    },
    {
        "message": "Individual policy message",
        // Policy specific nonComplianceMessage. You must include the policyDefinitionReferenceId as defined in the Policy Set.
        "policyDefinitionReferenceId": "ASC_DeployAzureDefenderForSqlAdvancedThreatProtectionWindowsAgent"
    }
],
```

## Defining `parameters`, `overrides` and `nonComplianceMessages` with a CSV file

Assigning single or multiple security and compliance focused Policy Sets (Initiatives), such as Azure Security Benchmark, NIST 800-53 r5, PCI, NIST 800-171, etc, with just JSON parameters becomes very complex fast. Add to this the complexity of overriding the effect if it is not surfaced as a parameter in the Policy Set using `overrides`. Finally, adding the optional `nonComplianceMessages` further increases the complexity.

To address the problem of reading and maintaining hundreds or thousands of JSON lines, EPAC can use the content of a spreadsheet (CSV) to create `parameters`, `overrides` and optionally `nonComplianceMessages` for a single Policy assignment `definitionEntry` or multiple Policy definitions (`definitionEntryList`).

!!! note
    This approach is best for very large Policy Sets such as Azure Security Benchmark, NIST 800-53, etc. Smaller Policy Sets should still be handled with JSON `parameters`, `overrides` and `nonComplianceMessages`.

Start by [generating documentation for one or more of those Policy Sets](documenting-assignments-and-policy-sets.md#policy-set-documentation), then modify the effect and parameter columns for each type of environment types you will use. In the example header below the infrastructure environments prod, test, dev, and sandbox are used as prefixes to the columns for Effect and Parameters respectively. Optionally you can add a column for `nonComplianceMessages`. If you want to switch from JSON to CSV, you can [generate this CSV file frm your already deployed Assignment(s)](documenting-assignments-and-policy-sets.md#assignment-documentation).

The CSV file generated contains the following headers/columns:

`name,referencePath,policyType,category,displayName,description,groupNames,policySets,allowedEffects,allowedOverrides,prodEffect,testEffect,devEffect,sandboxEffect,prodParameters,testParameters,devParameters,sandboxParameters,nonComplianceMessages`

Column explanations:

* `name` is the name of the policyDefinition referenced by the Policy Sets being assigned.
* `referencePath` is only used if the Policy is used more than once in at least one of the Policy Sets to disambiguate them. The format is `<policySetName>//<policyDefinitionReferenceId>`.
* `policyType`,`category`,`displayName`,`description`,`groupNames`,`policySets`,`allowedEffects` are optional and not used for deployment planning. They assist you in filling out the `<env>Effect` columns.
* `<env>Effect` columns must contain one of the allowedValues or allowedOverrides values. You define which scopes define each type of environment and what short name you give the environment type to use as a column prefix.
* `<env>Parameters` can contain additional parameters. You can also specify such parameters in JSON. EPAC will use the union of all parameters.
* `nonComplianceMessages` column is optional. The documentation script does not generate this columns.

EPAC will find the effect parameter name for each Policy in each Policy Set and use them. If no effect parameter is defined by the Policy Set, EPAC will use `overrides` to set the effect. EPAC will generate the `policyDefinitionReferenceId` for `nonComplianceMessages`.

After building the spreadsheet, you must reference the CSV file and the column prefix in each tree branch. `parameterFile` can be overridden in a child node; however, it is often used once per tree branch and defined adjacent to the `'definitionEntry` or `definitionEntryList`.

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

In the child nodes specifying the scope(s) specify which column prefix to use for selecting the CSV columns with `parameterSelector`. The actual prefix names have no meaning; they only need to match between the JSON below and the CSV file.

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

The element `nonComplianceMessageColumn` may appear anywhere in the tree. Definitions at a child override the previous setting. If no `nonComplianceMessageColumn` is specified, the spreadsheet is not used for the (optional) `nonComplianceMessages`.

```json
{
    "nodeName": "Prod/",
    "assignment": {
        "name": "pr-",
        "displayName": "Prod ",
        "description": "Prod Environment controls enforcement with initiative "
    },
    "parameterSelector": "prod",
    "nonComplianceMessageColumn": "nonComplianceMessages"
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

## Defining `resourceSelectors`

`resourceSelectors` may appear anywhere in the tree and are cumulative in any branch. [They follow the standard Azure Format](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/assignment-structure#resource-selectors-preview).

```json
"resourceSelectors": [
    {
        "name": "SDPRegions",
        "selectors": [
            {
                "kind": "resourceLocation",
                "in": [ "eastus", "westus", "centralus", "southcentralus" ]
            }
        ]
    }
]
```

## Defining `metadata`

`metadata` is sometimes used to track tickets for changes. Do NOT specify EPAC-reserved elements `roles` and `pacOwnerId`. For the final `metadata` EPAC creates the union of instances in the entire tree branch.

```json
"metadata": {
    "someItem": "Lorem Ipsum"
}
```

## Defining `enforcementMode`

`enforcementMode` is similar to the deprecated `ignoreBranch`; it deploys the assignment and sets the assignment to `Default` or `DoNotEnforce`. `DoNotEnforce` allows a what-if analysis. `enforcementMode` may appear anywhere in the tree. Definitions at a child override the previous setting.

```json
"enforcementMode": "DoNotEnforce",
```

## Example assignment files

### Simple Policy Assignment (Allowed Locations)

In the simple case an assignment is a single assignment or with no difference in `assignment`, `parameters`, and `definitionEntry` across multiple scopes. In many scenarios "Allowed Locations" is such a simple Assignment. Such Assignments do not have child nodes, just the root node.

```json
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

* `nodeName` is required for error messages; it's value is immaterial. EPAC concatenates them in the current tree branch.
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

```json
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

* In the following example we named our root node (`nodeName`) `/security/`. Since it is only used in case of error messages produced by EPAC during planning it's actual value doesn't matter as long as it's unique.
* We use a `definitionEntryList` to create two assignments at every leaf (six assignments total).
* For `assignment` string concatenation we append the strings in the `definitionEntryList` to the strings in the child nodes. You can see this best when you look at the `description` string in the child  nodes. It will form a sentence when concatenated by `append`ing the `definitionEntryList` `assignment` field `description`.
* The `parameters` specified in the children are specific to the IaC environment types and their `scope`. Note: a real assignment would define many more parameters. The set here is abbreviated since the actual set could easily exceed a hundred entries for each of the IaC environments. We'll see in the next example how to simplify large Policy Set parameters with a CSV file.

```json
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

  ```json
  "parameterFile": "security-baseline-parameters.csv",
   ```

* Setting the column prefix with `parameterSelector` to `prod`, `nonprod` and `sandbox`. For example:

  ```json
  "parameterSelector": "prod",
  ```

The CSV file is explained [above](#define-assignment-parameters-with-a-csv-file). The entire file is:

```json
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
* The children define the `tagName` parameter and the second part of the strings for `assignment`. The set of `parameters` is the union of the root node and the child node.
* This creates six Assignments (number of Policies assigned times number of children).

```json
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

```json
{
    "nodeName": "test",
    "scope": {
        "issue48": [
            "/providers/Microsoft.Management/managementGroups/issue48"
        ]
    },
    "assignment": {
        "displayName": "Audit virtual machines without disaster recovery configured",
        "description": "Some description",
        "name": "46332f3a51cb4bf2b4de78a7"
    },
    "definitionEntry": {
        "policyName": "0015ea4d-51ff-4ce3-8d8c-f3f8f0179a56" // Single policy definition
    },
    "nonComplianceMessages": [ // Array of nonComplianceMessages
        {
            "message": "Update non-compliance message" // Default nonComplianceMessage
        }
    ],
    "parameters": {}
}
```

### Non-Compliance Messages in a Policy Set Definition Assignment

An example of a policy assignment for a policy set definition with a default non-compliance message and a policy specific non-compliance message.

```json
{
    "nodeName": "test",
    "scope": {
        "issue48": [
            "/providers/Microsoft.Management/managementGroups/issue48"
        ]
    },
    "assignment": {
        "displayName": "Configure Azure Defender for SQL agents on virtual machines",
        "description": "Some other description",
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

```json
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
