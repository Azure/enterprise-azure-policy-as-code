# Policy Definitions

**On this page**

* [Policy Definition Files](#policy-definition-files)
* [Recommendations](#recommendations)
* [Example](#example)
* [Reading List](#reading-list)

## Policy Definition Files

Poliy definition files are managed within the the folder `policyDefintions` under `Definitions`.  The Policy definition files are structured based on the official [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy).

> **NOTE**:
> When authoring policy/initiative definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

The names of the definition JSON files don't matter, the Policy and Initiative definitions are registered based on the `name` attribute. It is recommended that you use a `GUID` as the `name`. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

## Recommendations

* `"name"` should be a GUID - see <https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-guid?view=powershell-7.2>.
* `"category"` should be one of the standard ones defined in built-in Policy definitions.
* Do not specify an `id`.
* Make the `effect` parameterized.
* Whenever feasible, provide a `defaultValue` for parameters, especially for an `effect` parameter.
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

## Reading List

* [Setup DevOps Environment](operating-environment.md) .
* [Create a source repository and import the source code](clone-github.md) from this repository.
* [Select the desired state strategy](desired-state-strategy.md)
* Copy starter kit pipeline definition and definition folder to your folders.
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.
* [Add custom Policy definitions](policy-definitions.md).
* [Add custom Policy Set definitions](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).
* Import Policies from the [Cloud Adoption Framework](cloud-adoption-framework.md).
* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](operational-scripts.md).

**[Return to the main page](../README.md)**
