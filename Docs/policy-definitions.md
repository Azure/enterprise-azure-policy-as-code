# Policies

**On this page**

* [Policy Definition Files](#policy-definition-files)
* [Recommendations](#recommendations)
* [Example](#example)
* [Reading List](#reading-list)

## Policy Definition Files

Policy definition files are managed within the the folder `policyDefintions` under `Definitions`.  The Policy definition files are structured based on the official [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy).

> **NOTE**:
> When authoring Policy and Policy definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

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
