# Policy Definitions

## Table of Contents

- [Policy Definition Files](#policy-definition-files)
- [Recommendations](#recommendations)
- [Example](#example)
- [Reading List](#reading-list)

## Policy Definition Files

The names of the definition JSON files don't matter, the Policy and Initiative definitions are registered based on the `name` attribute. It is recommended that you use a `GUID` as the `name`. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

> **NOTE**:
> When authoring policy/initiative definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

The Policy definition files are structured based on the official [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy).

<br/>

## Recommendations

- `"name"` should be a GUID - see <https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-guid?view=powershell-7.2>.
- `"category"` should be one of the standard ones defined in built-in Policy definitions.
- Do not specify an `id`.
- Make the `effect` parameterized.
- Whenever feasible, provide a `defaultValue` for parameters, especially for an `effect` parameter.
- Policy aliases are used by Azure Policy to refer to resource type properties in the `if` condition and in `existenceCondition`: <https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#aliases>.

<br/>

## Example

```json
{
    "name": "Newly created GUID",
    "properties": {
        "displayName": "Policy Display Name",
        "policyType": "Custom",
        "mode": "All",
        "description": "Policy Description",
        "metadata": {
            "version": "1.0.0",
            "category": "Your Category"
        },
        "parameters": {
            "YourParameter": {
                "type": "String",
                "metadata": {
                    "displayName": "YourParameter",
                    "description": "Your Parameter Description"
                }
            }
        },
        "policyRule": {
            "if": {
                "Insert Logic Here"
            },
            "then": {
                "effect": "Audit, Deny, Modify, etc.",
                "details": {
                    "roleDefinitionIds": [],
                    "operations": []
                }
            }
        }
    }
}
```

<br/>

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Define Policy Exemptions](../../Definitions/Exemptions/README.md)**

1. **[Documenting Assignments and Initiatives](../../Definitions/Documentation/README.md)**

1. **[Operational Scripts](../../Scripts/Operations/README.md)**

**[Return to the main page](../../README.md)**
