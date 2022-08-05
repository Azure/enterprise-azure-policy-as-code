
# Definitions and Global Settings

## Important

- `rootScope` is the place for Policy and Initiative definitions.
- Policy Assignments must be at this scope or below.
- Operational tasks, such as `Create-AzRemediationTasks.ps1`, must use the same rootScope or they will fail.

## Table of Content

* [Important](#important)
* [Table of Content](#table-of-content)
* [Folders](#folders)
* [Global Settings](#global-settings)
  * [managedIdentityLocation](#managedidentitylocation)
  * [globalNotScopes](#globalnotscopes)
  * [pacEnvironments](#pacenvironments)
* [Reading List](#reading-list)

## Folders

This folder and subfolders contain the definitions to deploy. Tasks:

1. Define the Azure environment in **[global-settings.jsonc](#global-settings)**
1. Create custom Policy definitions (optional) in folder **[Policies](Policies/README.md)**
1. Create custom Initiative definitions (optional) in folder **[Initiatives](Initiatives/README.md)**
1. Define the Policy Assignments in folder **[Assignments](Assignments/README.md)**
1. Define the Policy Exemptions in folder **[Define Policy Exemptions](../Definitions/Exemptions/README.md)**
1. Define Documentation in folder **[Documentation](../Definitions/Documentation/README.md)**

## Global Settings

File global-settings.jsonc defines the environments to deploy. It must be customized for each tenant or set of tenants. It and the **[Policy Assignments](Assignments/README.md)** are the only places where Azure tenant information is managed in source code.

The `PacEnvironmentSelector` argument to the scripts selects which values are used based on the argument provided to the script files. A literal string matches exactly. A star matches any value.

### managedIdentityLocation

```json
    "managedIdentityLocation": {
        "*": "eastus2"
    },
```

Policies with `Modify` and `DeployIfNotExists` effects require a Managed Identity for the remediation task. This section defines the location of the managed identity. It is often created in the tenant's primary location. This location can be overridden in the Policy Assignment files. The star in the example matches all `PacEnvironmentSelector` values. The prod section only applies to PaC `prod`. The two lists are added.

<br/>

### globalNotScopes

```json
    "globalNotScopes": {
        "*": [
            "/resourceGroupPatterns/synapseworkspace-managedrg-*",
            "/resourceGroupPatterns/managed-rg-*",
            "/resourceGroupPatterns/databricks-*",
            "/resourceGroupPatterns/DefaultResourceGroup*",
            "/resourceGroupPatterns/NetworkWatcherRG",
            "/resourceGroupPatterns/LogAnalyticsDefault*",
            "/resourceGroupPatterns/cloud-shell-storage*"
        ],
        "tenant": [
            "/providers/Microsoft.Management/managementGroups/mg-personal-subscriptions",
            "/providers/Microsoft.Management/managementGroups/mg-policy-as-code"
        ]
    },
```

Resource Group patterns allow us to exclude "special" managed Resource Groups. The exclusion is not dynamic. It is calculated when the deployment scripts execute.

The arrays can have the following entries:

| Scope type | Example |
|------------|---------|
| `managementGroups` | "/providers/Microsoft.Management/managementGroups/myManagementGroupId" |
| `subscriptions` | "/subscriptions/00000000-0000-0000-000000000000" |
| `resourceGroups` | "/subscriptions/00000000-0000-0000-000000000000/resourceGroups/myResourceGroup" |
| `resourceGroupPatterns` | No wild card or single *wild card at beginning or end of name or both; wild cards in the middle are invalid: <br/> "/resourceGroupPatterns/name" <br/> "/resourceGroupPatterns/name*" <br/> "/resourceGroupPatterns/*name" <br/> "/resourceGroupPatterns/*name*"

### pacEnvironments

pacEnvironments define the environment controlled by Policy as Code. It must be modified in each organization.

```json
"pacEnvironments": [
    {
        "pacSelector": "epac-dev",
        "cloud": "AzureCloud",
        "tenantId": "77777777-8888-9999-1111-222222222222",
        "defaultSubscriptionId": "11111111-2222-3333-4444-555555555555",
        "rootScope": {
            "SubscriptionId": "11111111-2222-3333-4444-555555555555"
        }
    },
    {
        "pacSelector": "epac-test",
        "cloud": "AzureCloud",
        "tenantId": "77777777-8888-9999-1111-222222222222",
        "defaultSubscriptionId": "99999999-8888-7777-4444-333333333333",
        "rootScope": {
            "SubscriptionId": "99999999-8888-7777-4444-333333333333"
        }
    },
    {
        "pacSelector": "tenant",
        "cloud": "AzureCloud",
        "tenantId": "77777777-8888-9999-1111-222222222222",
        "defaultSubscriptionId": "99999999-8888-7777-4444-333333333333",
        "rootScope": {
            "ManagementGroupName": "Contoso-Root"
        }
    }
]
```

Each entry in the array defines one of the environments:

| Element | Description |
|---------|-------------|
| `pacSelector` | Matches entry to `PacEnvironmentSelector`.  A star is not valid. |
| `cloud` | Azure environment. Examples: `"AzureCloud"`, `"AzureUSGovernment"`, `"AzureGermanCloud"`. Defaults to `"AzureCloud"` with a warning |
| `tenantId` | Azure Tenant Id |
| `defaultSubscriptionId` | Primary subscription for login. If the rootScope is a subscription, the default must match. |
| `rootScope` | Policy and Initiative definitions are **always** deployed at this scope. Must contain either a `MangementGroupName` or a `SubscriptionId` element |`

<br/>

<br/>

## Reading List

1. **[Pipeline](../Pipeline/README.md)**

1. **[Update Global Settings](#definitions-and-global-settings)**

1. **[Create Policy Definitions](../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../Definitions/Assignments/README.md)**

1. **[Define Policy Exemptions](../Definitions/Exemptions/README.md)**

1. **[Documenting Assignments and Initiatives](../Definitions/Documentation/README.md)**

1. **[Operational Scripts](../Scripts/Operations/README.md)**

**[Return to the main page](../README.md)**
