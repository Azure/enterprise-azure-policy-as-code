# Initiative Definitions

This chapter describes how Initiative (Policy Set) definitions are handled by the Policy-as-Code framework.

> **NOTE**:
> When authoring policy/initiative definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

The names of the definition JSON files don't matter, the Initiative definitions are registered based on the `name` attribute. It is recommended that you use a `GUID` as the `name`. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

<br/>[Back to top](#initiative-definitions)<br/>

## Initiative (Policy Set) Definition Files

The Initiative definition files are structured based on the official [Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy/tree/master/built-in-policies/policySetDefinitions).

**Optional:** Policy definition groups allow custom initiatives to map to different regulatory compliance requirements. These will show up in the regulatory compliance blade in Azure Security Center as if they were built-in. In order to use this, the custom initiative must have both policy definition groups and group names defined. Policy definition groups must be pulled from a built-in initiative such as the Azure Security Benchmark initiative.[Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub Azure Security Benchmark Code](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policySetDefinitions/Security%20Center/AzureSecurityCenter.json).

## Recommendations

- `"name"` should be a GUID - see <https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-guid?view=powershell-7.2>
- `"category"` should be one of the standard ones defined in built-in Policy definitions.
- Do **not*- specify a fully qualified `policyDefinitionName`. The solution adds the scope during deployment. **Warning**: Specifying the scope will break the deployment.
- Do not specify an `id`
- Make  the `effects` parameterized

## Example

```json
{
  "name": "Newly created GUID",
  "properties": {
    "displayName": "Your Initiative Display Name",
    "description": "Initiative Description",
    "metadata": {
      "version": "1.0.0",
      "category": "Category Name"
    },
    "policyDefinitionGroups": [
      {
        "name": "Azure_Security_Benchmark_v2.0_NS-1",
        "additionalMetadataId": "/providers/Microsoft.PolicyInsights/policyMetadata/Azure_Security_Benchmark_v2.0_NS-1"
      }
    ],
    "parameters": {
      "Parameter for policy one": {
        "type": "Array",
        "defaultValue": []
      },
      "Parameter for policy two": {
        "type": "string",
        "defaultValue": []
      }
    },
    "PolicyDefinitions": [
      {
        "policyDefinitionReferenceId": "Reference to policy number one",
        "policyDefinitionName": "Name of Policy Number One",
        "parameters": {
          "Parameter for policy one": {
            "value": "[parameters('Parameter for policy one')]"
          }
        }
      },
      {
        "policyDefinitionReferenceId": "Reference to policy number two",
        "policyDefinitionName": "Name of Policy Number Two",
        "parameters": {
          "Parameter for policy two": {
            "value": "[parameters('Parameter for policy two')]"
          }
        },
        "groupNames": [
            "Azure_Security_Benchmark_v2.0_NS-1"
        ]
      }
    ]
  }
}
```

## Merging Built-In Initiatives

There are use cases where it's beneficiary to merge 1 or more built-in initiatives into a custom initiative.

- Merging Initiatives for compliance coverage
- Removing Policies
- Swapping out a built-in Policy with no `Deny` effect for a custom one with `Deny`
- Importing Policy Definition Groups instead of copy/paste
- Surfacing hidden parameters
- Hiding parameters
- Hard-coding parameters

### Limitations Imposed by Azure

The script writes a message and truncates the merged Initiative to keep within the limits.

- Number of Definition Groups: 1000
- Number of Group names per Policy Definition: 16

### Example

```json
    "merge": {
        // "substitutePolicyDefinitions": [
        //     {
        //         "oldName": "",
        //         "newName": "" // if omitted, delete the referenced Policy definition
        //     }
        // ],
        // "groupDefinitionsImport": [
        //     "1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
        // ],
        "initiatives": [
            // 1. Enter array in order of descending preference
            // 2. Initiatives must be built-in
            {
                "initiativeNameOrId": "03055927-78bd-4236-86c0-f36125a10dc9" // NIST SP 800-171 Rev. 2
            },
            {
                "initiativeNameOrId": "1f3afdf9-d0c9-4c3d-847f-89da613e70a8" // Azure Security Benchmark
                // "parameterChanges": { NOT YET IMPLEMENTED
                //     "surface": [
                //         {
                //             "referenceId": "",
                //             "parameterName": "",
                //             "defaultValue": "" // optional
                //         }
                //     ],
                //     "hide": [
                //         {
                //             "referenceId": "",
                //             "parameterName": "",
                //             "parameterValue": "" // can be a reference to a common parameter, if not specified use Policy default
                //         }
                //     ],
                //     "default": [
                //         {
                //             "parameterName": "",
                //             "parameterValue": "" // can be a reference to a common parameter, if not specified use Policy default
                //         }
                //     ]
                // }
            }
        ]
    },
```

| Element | Description |
|---------|-------------|
| `merge` | Contains the merge instructions. |
| `initiatives` | List of initiatives to merge. May specify parameter changes. |
| Not Yet Implemented <br/> `substitutePolicyDefinitions` | Replaces Policy `oldName` with `newName`. if `newName` omitted, delete the referenced Policy definition(s). |
| Not Yet Implemented <br/> `groupDefinitionsImport` | Imports only the Group Definitions. the Policy definitions are used from this file only. |
| Not Yet Implemented <br/> `parameterChanges` | Allows `surface`, `hide` and `default` actions on parameters in a Policy Definition. |

[Back to top](#initiative-definitions)<br/>

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](#initiative-definitions)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Scripts](../../Scripts/README.md)**

**[Return to the main page](../../README.md)**
<br/>[Back to top](#initiative-definitions)<br/>
