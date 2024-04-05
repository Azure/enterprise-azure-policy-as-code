# Policy Set (Initiative) Definitions

## Initiative (Policy Set) Definition Files

Policy Set definition files are managed within the folder `policySetDefinitions` under `Definitions`. The definition files are structured based on the official [Azure Initiative definition structure](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) published by Microsoft. There are numerous definition samples available on Microsoft's [GitHub repository for azure-policy](https://github.com/Azure/azure-policy/tree/master/built-in-policies/policySetDefinitions).

The names of the definition JSON files don't matter, the Policy Sets are registered based on the `name` attribute. The solution also allows the use of JSON with comments by using `.jsonc` instead of `.json` for the file extension.

### Policy Definition Groups

**Optional:** Policy definition groups allow custom Policy Sets to map to different regulatory compliance requirements. These will show up in the regulatory compliance blade in Azure Security Center as if they were built-in. In order to use this, the custom Policy Sets must have both policy definition groups and group names defined.

- Policy definition groups must be pulled from a built-in Policy Sets, such as, the [`Microsoft cloud security benchmark` Policy Set](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policySetDefinitions/Security%20Center/AzureSecurityCenter.json).
- Policy definition groups can be imported by using `importPolicyDefinitionGroups`. The following imports the groups from Azure Security Benchmark.

```jsonc
"importPolicyDefinitionGroups": [
  // built-in Policy Set definition "Microsoft cloud security benchmark"
  "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
],
```

## JSON Schema

The GitHub repo contains a JSON schema which can be used in tools such as [VS Code](https://code.visualstudio.com/Docs/languages/json#_json-schemas-and-settings) to provide code completion.

To utilize the schema add a ```$schema``` tag to the JSON file.

```
{
  "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-set-definition-schema.json"
}
```

## Recommendations

* `"name"` is required and should be unique. It can be a GUID or a unique short name.
* `"category"` should be one of the standard ones defined in built-in Policies.
* Custom Policies: must use `policyDefinitionName`. The solution constructs the `policyDefinitionId` based on the `deploymentRootScope` in `global-settings.jsonc`.
* Builtin Policies: must use `policyDefinitionId`.
* Do **not** specify an `id`. The solution will ignore it.
* Make  the `effects` parameterized

## Metadata

It is customary to include a `category` and a `version` in the `metadata` section. The `category` should be one of the standard ones defined in built-in Policy Sets. The `version` should be a semantic version number.

EPAC injects `deployedBy` into the `metadata` section. This is a string that identifies the deployment source. It defaults to `epac/$pacOwnerId/$pacSelector`. You can override this value in `global-settings.jsonc`

**Not recommended:** Adding `deployedBy` to the `metadata` section in the Policy definition file will override the value for this definition only from `global-settings.jsonc` or default value.

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
    "policyDefinitions": [
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
