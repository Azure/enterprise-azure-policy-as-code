# Initiative Definitions

## Table of Contents

- [Initiative (Policy Set) Definition Files](#initiative--policy-set--definition-files)
- [Recommendations](#recommendations)
- [Example](#example)
- [Reading List](#reading-list)

## Initiative (Policy Set) Definition Files

The names of the definition JSON files don't matter, the Initiative definitions are registered based on the `name` attribute. It is recommended that you use a `GUID` as the `name`. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

> **NOTE**:
> When authoring policy/initiative definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

The Initiative definition files are structured based on the official [Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy/tree/master/built-in-policies/policySetDefinitions).

**Optional:** Policy definition groups allow custom initiatives to map to different regulatory compliance requirements. These will show up in the regulatory compliance blade in Azure Security Center as if they were built-in. In order to use this, the custom initiative must have both policy definition groups and group names defined. Policy definition groups must be pulled from a built-in initiative such as the Azure Security Benchmark initiative.[Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub Azure Security Benchmark Code](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policySetDefinitions/Security%20Center/AzureSecurityCenter.json).

## Recommendations

- `"name"` should be a GUID - see <https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-guid?view=powershell-7.2>
- `"category"` should be one of the standard ones defined in built-in Policy definitions.
- Do **not*- specify a fully qualified `policyDefinitionName`. The solution adds the scope during deployment. **Warning**: Specifying the scope will break the deployment.
- Do not specify an `id`
- Make  the `effects` parameterized

<br/>

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

<br/>

## Merging Built-In Initiatives

**WARNING:** Feature removed in 2.2

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](#initiative-definitions)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Define Policy Exemptions](../../Definitions/Exemptions/README.md)**

1. **[Documenting Assignments and Initiatives](../../Definitions/Documentation/README.md)**

1. **[Operational Scripts](../../Scripts/Operations/README.md)**

**[Return to the main page](../../README.md)**
<br/>
