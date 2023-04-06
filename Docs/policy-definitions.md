# Policies

## Policy Definition Files

Policy definition files are managed within the the folder `policyDefintions` under `Definitions`.  The Policy definition files are structured based on the official [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy).

!!! note
    When authoring Policy and Policy definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

The names of the definition JSON files don't matter, the Policy and Policy Set definitions are registered based on the `name` attribute. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

## Recommendations

* `"name"` is required and should be unique. It can be a GUID or a unique short name.
* `"category"` should be one of the standard ones defined in built-in Policies.
* Do not specify an `id`. The solution will ignore it.
* Make the `effect` parameterized. Always use the parameter name `effect`.
* Whenever feasible, provide a `defaultValue` for parameters, especially for the `effect` parameter.
* Policy aliases are used by Azure Policy to refer to resource type properties in the `if` condition and in `existenceCondition`: <https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#aliases>.

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
