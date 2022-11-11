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

## Recommendations

- `"name"` should be a GUID - see <https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-guid?view=powershell-7.2>.
- `"category"` should be one of the standard ones defined in built-in Policy definitions.
- Do not specify an `id`.
- Make the `effect` parameterized.
- Whenever feasible, provide a `defaultValue` for parameters, especially for an `effect` parameter.
- Policy aliases are used by Azure Policy to refer to resource type properties in the `if` condition and in `existenceCondition`: <https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#aliases>.

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

## Reading List

- [Pipeline - Azure DevOps](azure-devops-pipeline.md)
- [Update Global Settings](definitions-and-global-settings.md)
- [Create Policy Definitions](policy-definitions.md)
- [Create Policy Set (Initiative) Definitions](policy-set-definitions.md)
- [Define Policy Assignments](policy-assignments.md)
- [Define Policy Exemptions](policy-exemptions.md)
- [Documenting Assignments and Initiatives](documenting-assignments-and-policy-sets.md)
- [Operational Scripts](operational-scripts.md)
- **[Cloud Adoption Framework Policies](cloud-adoption-framework.md)**

**[Return to the main page](../README.md)**
