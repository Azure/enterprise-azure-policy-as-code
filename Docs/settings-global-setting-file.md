# Global Settings

<div style="margin: 30px 0; position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%; height: auto;">
  <iframe src="https://www.youtube.com/embed/EGjjeaYMCWQ" 
          style="position: absolute; top:0; left:0; width:100%; height:100%;" 
          frameborder="0" 
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
          allowfullscreen>
  </iframe>
</div>

## Overview

`global-settings.jsonc` has following sections explained below:

| Setting | Description |
|---------|-------------|
| `telemetryOptOut` | If set to true disables the collection of usage data for the EPAC repo. The default is false. See [Usage Tracking](index.md#telemetry-tracking-using-customer-usage-attribution-pid) for more information. |
| `pacOwnerId` | Uniquely identifies deployments from a specific repo. We recommend using a GUID. |
| `pacEnvironments` | Defines the EPAC environments. |

### Example with Required Elements

```json
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json",
    "pacOwnerId": "00000000-0000-0000-0000-000000000000",
    "pacEnvironments": [
        {
            "pacSelector": "epac-dev",
            "cloud": "AzureCloud",
            "tenantId": "00000000-0000-0000-0000-000000000000",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/mg-Epac-Dev",
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false,
                "doNotDisableDeprecatedPolicies": false
            },
            "skipResourceValidationForExemptions": false,
            "managedIdentityLocation": "eastus2"
        },
        {
            "pacSelector": "tenant",
            "cloud": "AzureCloud",
            "tenantId": "00000000-0000-0000-0000-000000000000",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/mg-Enterprise",
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false,
                "doNotDisableDeprecatedPolicies": false
            },
            "skipResourceValidationForExemptions": false,
            "managedIdentityLocation": "eastus2",
            "globalNotScopes": [
                "/providers/Microsoft.Management/managementGroups/mg-Epac-Dev"
            ]
        }
    ]
}
```

## JSON Schema

The GitHub repo contains a JSON schema which can be used in tools such as [VS Code](https://code.visualstudio.com/Docs/languages/json#_json-schemas-and-settings) to provide code completion.

To utilize the schema add a ```$schema``` tag to the JSON file.

```
{
  "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
}
```

## Opt out of telemetry data collection `telemetryOptOut`

Starting with v8.0.0, Enterprise Policy as Code (EPAC) is tracking the usage using Customer Usage Attribution (PID). See [Usage Tracking](index.md#telemetry-tracking-using-customer-usage-attribution-pid) for more information on opt out. Default is false.

```json
"telemetryOptOut": true,
```

## Uniquely identify deployments with `pacOwnerId`

`pacOwnerId` is required for [desired state handling](settings-desired-state.md) to distinguish Policy resources deployed via this EPAC repo, legacy technology, another EPAC repo, or another Policy as Code solution.

## Define EPAC Environments in `pacEnvironments`

EPAC has a concept of an environment identified by a string (unique per repository) called `pacSelector`. The `pacSelector` is just a name. We highly recommend to call the Policy development environment `epac-dev`, you can name the EPAC prod environments in a way which makes sense to you in your environment. We use `tenant`, in our samples and documentation. These names are used and therefore must match:

- Defining the association (`pacEnvironments`) of an EPAC environment.
- Script parameter when executing different deployment stages in a CI/CD pipeline or semi-automated deployment targeting a specific EPAC environments.
- `scopes`, `notScopes`, `additionalRoleAssignments`, `managedIdentityLocations`, and `userAssignedIdentity` definitions in Policy Assignment JSON files.

`pacEnvironments` entries associate:

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `pacSelector` | The logical name of the EPAC environment. This should be lower case whenever used throughout an EPAC project. |
| `cloud` | Select cloud environments. |
| `tenantId` | Enables multi-tenant scenarios. |
| `deploymentRootScope` | The deployment scope for Policy and Policy Set definitions. Policy Assignments can only defined at this scope and child scopes (recursive). See deployment scope formats below. |
| `desiredState.strategy` | Defines the desired state strategy. See [Desired State Strategy](settings-desired-state.md). |
| `keepDfcSecurityAssignments` | See [Managing Defender for Cloud Policy Assignments](settings-dfc-assignments.md). |
| `doNotDisableDeprecatedPolicies` | Automatically set deprecated policies' policy effect to "Disabled". This setting can be used to override that behavior by setting it to `true`. Default is `false`. |
| `managedIdentityLocation` | See [DeployIfNotExists and Modify Policy Assignments need `managedIdentityLocation`](#deployifnotexists-and-modify-policy-assignments-need-managedidentitylocation) |

#### Deployment Scope Formats

| Scope Level | Format |
|-------------|--------|
| Management Group | `/providers/Microsoft.Management/managementGroups/{management-group-name}` |
| Subscription | `/subscriptions/{subscription-id}` |
| Resource Group | `/subscriptions/{subscription-id}/resourceGroups/{resource-group-name}` |

### Optional Parameters

| Parameter | Description |
|-----------|-------------|
| `globalNotScopes` | See [Excluding scopes for all Assignments with `globalNotScopes`](#excluding-scopes-for-all-assignments-with-globalnotscopes) |
| `skipResourceValidationForExemptions` | Disables checking the resource existence for Policy Exemptions. Default is false. This can be useful if you have a massive amount of exemptions and the validation is taking too long. |
| `deployedBy` | Populates the `metadata` fields. It defaults to `epac/$pacOwnerId/$pacSelector`. We recommend to use the default. |
| `managedTenantId` | Used when the `pacEnvironment` is in a lighthouse managed tenant. |
| `defaultContext` | In rare cases (typically only when deploying to a lighthouse managed tenant) the default context (Get-azContext) of a user/SPN running a plan will be set to a subscription where that user/SPN does not have sufficient privileges. Some checks have been built in so that in some cases when this happens EPAC is able to fix the context issue. When it is not, a `defaultContext` subscription name must be provided. This can be any subscription within the `deploymentRootScope`. |
| `keepDfcPlanAssignments` | [Managing Defender for Cloud Assignments](settings-dfc-assignments.md). |

#### Metadata Field Usage

| Resource Type | Metadata Field | Description |
|---------------|----------------|-------------|
| Policy Definitions, Policy Set Definitions, Policy Exemptions | `metadata.deployedBy` | Populated with the `deployedBy` value |
| Policy Assignments | `metadata.assignedBy` | Populated with the `deployedBy` value (Azure Portal displays it as 'Assigned by') |
| Role Assignments | `description` | The value is added to the description field since Role assignments do not contain metadata |

### DeployIfNotExists and Modify Policy Assignments need `managedIdentityLocation`

Policies with `Modify` and `DeployIfNotExists` effects require a Managed Identity for the remediation task. This section defines the location of the managed identity. It is often created in the tenant's primary location. This location can be overridden in the Policy Assignment files. The star in the example matches all `pacEnvironmentSelector` values.

```json
    "managedIdentityLocation": {
        "*": "eastus2"
    },
```

### Excluding scopes for all Assignments with `globalNotScopes`

The arrays can have the following entries:

| Scope type | Example |
|------------|---------|
| `managementGroups` | `"/providers/Microsoft.Management/managementGroups/myManagementGroupId"` |
| `subscriptions` | `"/subscriptions/00000000-0000-0000-000000000000"` |
| `resourceGroups` | `"/subscriptions/00000000-0000-0000-000000000000/resourceGroups/myResourceGroup"` |
| Resource group pattern | `"/subscriptions/*/resourceGroups/myResourceGroupPattern*"` |

Resource Group patterns allow us to exclude "special" managed Resource Groups. The exclusion is not dynamic. It is calculated when the deployment scripts execute.

```json
"globalNotScopes": [
    "/subscriptions/*/resourceGroups/synapseworkspace-managedrg-*",
    "/subscriptions/*/resourceGroups/managed-rg-*",
    "/providers/Microsoft.Management/managementGroups/mg-personal-subscriptions",
    "/providers/Microsoft.Management/managementGroups/mg-policy-as-code"
]
```

### Example for Lighthouse Manged Tenant

```json
{
    "pacOwnerId": "00000000-0000-0000-0000-000000000000",
    "pacEnvironments": [
        {
            "pacSelector": "epac-dev",
            "cloud": "AzureCloud",
            "tenantId": "11000000-0000-0000-0000-000000000000",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/PAC-Heinrich-Dev",
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false,
                "doNotDisableDeprecatedPolicies": false
            },
            "skipResourceValidationForExemptions": false,
            "mangedIdentityLocation": "eastus2"
        },
        {
            "pacSelector": "tenant",
            "cloud": "AzureCloud",
            "tenantId": "11000000-0000-0000-0000-000000000000",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/Contoso-Root",
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false,
                "doNotDisableDeprecatedPolicies": false
            },
            "globalNotScopes": [
                "/providers/Microsoft.Management/managementGroups/PAC-Heinrich-Dev"
            ],
            "skipResourceValidationForExemptions": false,
            "managedIdentityLocation": "eastus2"
        },
        {
            "pacSelector": "lightHouseTenant",
            "cloud": "AzureCloud",
            "tenantId": "11000000-0000-0000-0000-000000000000",
            "managedTenantId": "22000000-0000-0000-0000-000000000000",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/Contoso-Root",
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false,
                "doNotDisableDeprecatedPolicies": false
            },
            "skipResourceValidationForExemptions": false,
            "managedIdentityLocation": "eastus2"
        }
    ]
}
```
