# Policy Set (Initiative) Definitions

**On this page**

* [Initiative (Policy Set) Definition Files](#initiative-policy-set-definition-files)
* [Recommendations](#recommendations)
* [Example](#example)
* [Merging Built-In Initiatives](#merging-built-in-initiatives)
* [Reading List](#reading-list)

## Initiative (Policy Set) Definition Files

Policy Set definition files are managed within the the folder `policySetDefinitions` under `Definitions`. The definition files are structured based on the official [Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy/tree/master/built-in-policies/policySetDefinitions).

> **NOTE**:
> When authoring Policy or Policy Set definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

The names of the definition JSON files don't matter, the Policy Sets are registered based on the `name` attribute. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

**Optional:** Policy definition groups allow custom Policy Sets to map to different regulatory compliance requirements. These will show up in the regulatory compliance blade in Azure Security Center as if they were built-in. In order to use this, the custom Policy Sets must have both policy definition groups and group names defined.

* Policy definition groups must be pulled from a built-in Policy Sets such as the Azure Security Benchmark initiative ([Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft). There are numerous definition samples available on Microsoft's [GitHub Azure Security Benchmark Code](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policySetDefinitions/Security%20Center/AzureSecurityCenter.json).
* Policy definition groups can be imported by using `importPolicyDefinitionGroups`. The following imports the groups from Azure Security Benchmark.

```json
    "importPolicyDefinitionGroups": [
      // built-in Policy Set definition (ASB v3)
      "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
    ],
```

## Recommendations

* `"name"` is required and should be unique. It can be a GUID or a unique short name.
* `"category"` should be one of the standard ones defined in built-in Policies.
* Custom Policies: use `policyDefinitionName`. The solution constructs the `policyDefinitionId` based on the `deploymentRootScope` in `global-settings.jsonc`.
* Builtin Policies: use `policyDefinitionId`. The solution can constructs the `policyDefinitionId` from `policyDefinitionName` for builtin Policies; however using `policyDefinitionId` is more explicit/cleaner.
* Do **not** specify an `id`. The solution will ignore it.
* Make  the `effects` parameterized

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
      },
      {
        "policyDefinitionReferenceId": "Reference to policy number two",
        "policyDefinitionId": "id of a builtin Policy",
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
