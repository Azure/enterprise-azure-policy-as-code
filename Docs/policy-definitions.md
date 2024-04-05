# Policy Definitions

## Policy Definition Files

Policy definition files are managed within the folder `policyDefinitions` under `Definitions`.  The Policy definition files are structured based on the official [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy).

The names of the definition JSON files don't matter, the Policy and Policy Set definitions are registered based on the `name` attribute. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

## JSON Schema

The GitHub repo contains a JSON schema which can be used in tools such as [VS Code](https://code.visualstudio.com/Docs/languages/json#_json-schemas-and-settings) to provide code completion.

To utilize the schema add a ```$schema``` tag to the JSON file.

```
{
  "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
}
```

This schema is new in v7.4.x and may not be complete. Please let us know if we missed anything.

## Recommendations

* `"name"` is required and should be unique. It can be a GUID or a unique short name.
* `"category"` should be one of the standard ones defined in built-in Policies.
* Do not specify an `id`. The solution will ignore it.
* Make the `effect` parameterized. Always use the parameter name `effect`.
* Whenever feasible, provide a `defaultValue` for parameters, especially for the `effect` parameter.
* Policy aliases are used by Azure Policy to refer to resource type properties in the `if` condition and in `existenceCondition`: <https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#aliases>.

## Metadata

It is customary to include a `category` and a `version` in the `metadata` section. The `category` should be one of the standard ones defined in built-in Policies. The `version` should be a semantic version number.

EPAC injects `deployedBy` into the `metadata` section. This is a string that identifies the deployment source. It defaults to `epac/$pacOwnerId/$pacSelector`. You can override this value in `global-settings.jsonc`

**Not recommended:** Adding `deployedBy` to the `metadata` section in the Policy definition file will override the value for this definition only from `global-settings.jsonc` or default value.

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
            "effect": {
                "type": "String",
                "metadata": {
                    "displayName": "Effect",
                    "description": "Enable or disable the execution of the policy",
                },
                "allowedValues": [
                    "Audit",
                    "Deny",
                    "Disabled"
                ],
                "defaultValue": "Audit"
            },
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
                "effect": "[parameters('effect')]",
            }
        }
    }
}
```
