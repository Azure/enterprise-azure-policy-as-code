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
| `manageChildScopeDefinitions` | When `true`, EPAC manages Policy Definitions and Policy Set Definitions at child scopes (child management groups, subscriptions) under the `deploymentRootScope`, making them eligible for deletion. Default is `false`. See [Managing Child Scope Definitions](settings-desired-state.md#managing-child-scope-definitions). |
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
| `filterRoleAssignmentsByEffect` | Reduces the role assignments created for Policy Set assignments. Default is true. See [Reducing role assignments with `filterRoleAssignmentsByEffect`](#reducing-role-assignments-with-filterroleassignmentsbyeffect). |
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

### Reducing role assignments with `filterRoleAssignmentsByEffect`

The Managed Identity of a Policy Set assignment can be granted the union of the `roleDefinitionIds` of **every** member Policy, whatever effect each member evaluates with. Some built-in Policy Sets hard-code a member's effect to a non-deploying value such as `AuditIfNotExists`, so those members never deploy anything, yet their roles are still granted. Microsoft Cloud Security Benchmark v2 is the most visible example: it would grant eight roles, seven of which - including `Contributor`, `User Access Administrator` and `Azure Event Hubs Data Owner` - come only from members hard-coded to `AuditIfNotExists`.

`filterRoleAssignmentsByEffect` defaults to `true`, which omits a role when it is **only** contributed by member Policies whose effect the Policy Set hard-codes to a literal, non-deploying effect: `Audit`, `AuditIfNotExists`, `Deny`, `DenyAction`, `Disabled`, `Append`, `Manual` or `AddToNetworkGroup`.

A Policy Set may also pin a member's effect to an ARM expression, for example `[if(contains(parameters('resourceTypeList'),'microsoft.aad/domainservices'),parameters('effect'),'Disabled')]`. Such an expression is evaluated by Azure at assignment time and can resolve to a deploying effect, so those members always keep their roles. The same applies to any effect value EPAC does not recognise.

Set it to `false` to temporarily restore the previous behaviour of granting the union of all member roles:

```json
    "filterRoleAssignmentsByEffect": false,
```

A hard-coded effect is only a default. An assignment may use an [override](policy-assignments.md#defining-overrides-with-json) of kind `policyEffect` to raise a member back to `DeployIfNotExists` or `Modify`, and Azure accepts that even when the Policy Set pins the effect. EPAC therefore keeps the roles of any member an override raises to a deploying effect. Roles are also kept when:

- another member which is not hard-coded contributes the same role, or
- the assignment has a deploying `policyEffect` override which cannot be attributed to specific `policyDefinitionReferenceId` values.

The setting is deliberately narrow. It does not change:

- **Assignments of a single Policy.** Only Policy Set assignments are filtered, so a `DeployIfNotExists` or `Modify` Policy assigned on its own always keeps every role its definition declares, even if the assignment overrides it to `Disabled`.
- **Policy Sets which do not hard-code effects.** When a member takes its effect from its own definition default or from a Policy Set parameter, it is not hard-coded and its roles are always kept.
- **`additionalRoleAssignments`.** These are read from the Policy Assignment file and appended after the Policy derived roles are calculated. They never pass through the filter, so they are granted in full at the scope you specify. This is what makes them a reliable way to add back a role the filter removes.

#### Assignments which pin `definitionVersion`

Members and hard-coded member effects change between published versions of a Policy Set. When an assignment pins a `definitionVersion`, EPAC resolves that version from the Policy Set's published version history and calculates the roles from it, rather than from the latest version. Wildcards are resolved to the highest matching version, preferring a stable version and falling back to a pre-release only when no stable version matches the pattern.

This version-aware calculation applies whether or not `filterRoleAssignmentsByEffect` is enabled, so a version-pinned assignment may see its roles change even with filtering off. If the version history cannot be read - a custom Policy Set with no published versions, a cloud which does not expose the endpoint, or a pattern which matches nothing - EPAC falls back to the latest version and keeps every role.

> [!WARNING]
> This setting narrows the permissions granted to the Managed Identity. The roles it removes are contributed only by members which cannot deploy anything, so remediation is not affected, but the role assignments themselves are deleted from Azure on the next deployment of the roles plan.
>
> Review the roles plan before deploying. Use `additionalRoleAssignments` in the Policy Assignment file to add back any role your remediation still needs.

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
