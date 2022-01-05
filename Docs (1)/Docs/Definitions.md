# Policy and Initiative Definitions

This chapter describes how Policy and Initiative (Policy Set) Definitions are handled by the Policy-as-Code framework. To learn about how these definitions are used, see the Assignments section.
Policy and Initiative (Policy Set) Definitions do not evaluate resources until they are assigned to a specific scope with an Assignment.

The components required for **creating / updating / deleting Policy and Initiative definitions** are the following:

| Component | What is it used for? |
|--|--|
| **Policy Definition JSON files** | Policy definitions files define what a custom Policy is able to do, what its name is, and more. |
| **Initiative Definition JSON files** | Initiative definition files define what policies a custom initiative contains, what its name is, and more. |
| **Definition configuration scripts** | These scripts are used for creating / updating / deleting Policy definitions in Azure. These definitions are registered in the chosen scope (by default in the Tenant Root Group). |
| **Deployment Pipeline** | This pipeline invokes the configuration scripts that register custom policy and initiative definitions in the scope provided. It is set to be triggered on any changes of the Policies folder in the Components repository. |


> **NOTE**:
> When authoring policy/initiative definitions, check out the [Maximum count of Azure Policy objects](https://docs.microsoft.com/en-us/azure/governance/policy/overview#maximum-count-of-azure-policy-objects)

## Policy Definition JSON files

The Policy and Initiative definition files are structured based on the official [Azure Policy definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy).

The names of the definition JSON files don't matter, the Policy and Initiative definitions are registered based on the `name` attribute defined in the JSON's `properties`. Here is an example policy definition structure:
```json
{
    "name": "Newly created GUID - https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-guid?view=powershell-7.2",
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
## Initiative Definition JSON files

The Initiative definition files are structured based on the official [Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy/tree/master/built-in-policies/policySetDefinitions).

OPTIONAL: Policy definition groups allow custom initiatives to map to different regulatory compliance requirements. These will show up in the regulatory compliance blade in Azure Security Center as if they were built-in. In order to use this, the custom initiative must have both policy definition groups and group names defined. Policy definition groups must be pulled from a built-in initiative such as the Azure Security Benchmark initiative.[Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub Azure Security Benchmark Code](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policySetDefinitions/Security%20Center/AzureSecurityCenter.json).

The names of the definition JSON files don't matter, the Policy and Initiative definitions are registered based on the `name` attribute defined in the JSON's `properties`. Here is an example policy definition structure:
```json
{
  "name": "Newly created GUID - https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/new-guid?view=powershell-7.2",
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
## Policy Aliases
 - Policy aliases are used by Azure Policy to refer to resource type properties. You will need to use these when writing custom policies to manage different resources.
https://docs.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure#aliases

## Next steps
Read through the rest of the documentation and configure the pipeline to your needs.

- **[Pipeline](./pipeline.md)**
- **[Assignments](./Assignments.md)**
- **[Scripts and Configuration Files](./ScriptsAndConfigurationFiles.md)**
- **[Quick Start guide](../readme.md)**

[Return to the main page.](../readme.md)