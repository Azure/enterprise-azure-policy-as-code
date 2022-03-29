
# Definitions and Global Settings

## Important

- `rootScope` is the place for Policy and Initiative definitions.
- Policy Assignments must be at this scope or below.
- Operational tasks, such as `Create-AzRemediationTasks.ps1`, must use the same rootScope or they will fail.

This folder and subfolders contain the definitions to deploy. Tasks:

1. Define the Azure environment in **[global-settings.jsonc](#global-settings)**
1. Create custom Policy definitions (optional) in folder **[Policies](Policies/README.md)**
1. Create custom Initiative definitions (optional) in folder **[Initiatives](Initiatives/README.md)**
1. Define the Policy Assignments in folder **[Policy Assignments](Assignments/README.md)**

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

<br/>[Back to top](#definitions-and-global-settings)<br/>

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
        "prod": [
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
            "pacSelector": "dev",
            "tenantId": "00000000-0000-0000-000000000000",
            "defaultSubscriptionId": "00000000-0000-0000-000000000000",
            "rootScope": {
                "SubscriptionId": "00000000-0000-0000-000000000000"
            }
        },
        {
            "pacSelector": "test",
            "tenantId": "00000000-0000-0000-000000000000",
            "defaultSubscriptionId": "00000000-0000-0000-000000000000",
            "rootScope": {
                "SubscriptionId": "00000000-0000-0000-000000000000"
            }
        },
        {
            "pacSelector": "prod",
            "tenantId": "00000000-0000-0000-000000000000",
            "defaultSubscriptionId": "00000000-0000-0000-000000000000",
            "rootScope": {
                "ManagementGroupName": "Contoso-Root"
            }
        }
    ],
```

Each entry in the array defines one of the environments:

| Element | Description |
|---------|-------------|
| `pacSelector` | Matches entry to `PacEnvironmentSelector`.  A star is not valid. |
| `tenantId` | Azure Tenant Id |
| `defaultSubscriptionId` | Primary subscription for login. If the rootScope is a subscription, the default must match. |
| `rootScope` | Policy and Initiative definitions are **always** deployed at this scope. |

<br/>[Back to top](#definitions-and-global-settings)<br/>

### representativeAssignments

`representativeAssignments` is used by `Get-AzEffectsForEnvironments.ps1` to calculate a spreadsheet containing the effective effects for each Policy assigned.

```json
    "representativeAssignments": [
        {
            "environmentType": "PROD",
            "policyAssignments": [
                "/providers/Microsoft.Management/managementGroups/Contoso-Prod/providers/Microsoft.Authorization/policyAssignments/prod-asb",
                "/providers/Microsoft.Management/managementGroups/Contoso-Prod/providers/Microsoft.Authorization/policyAssignments/prod-org"
            ]
        },
        {
            "environmentType": "NONPROD",
            "policyAssignments": [
                "/providers/Microsoft.Management/managementGroups/Contoso-NonProd/providers/Microsoft.Authorization/policyAssignments/nonprod-asb",
                "/providers/Microsoft.Management/managementGroups/Contoso-NonProd/providers/Microsoft.Authorization/policyAssignments/nonprod-org"
            ]
        },
        {
            "environmentType": "DEV",
            "policyAssignments": [
                "/providers/Microsoft.Management/managementGroups/Contoso-Dev/providers/Microsoft.Authorization/policyAssignments/dev-asb",
                "/providers/Microsoft.Management/managementGroups/Contoso-Dev/providers/Microsoft.Authorization/policyAssignments/dev-org"
            ]
        },
        {
            "environmentType": "SANDBOX",
            "policyAssignments": [
                "/providers/Microsoft.Management/managementGroups/Contoso-Sandbox/providers/Microsoft.Authorization/policyAssignments/sandbox-asb",
                "/providers/Microsoft.Management/managementGroups/Contoso-Sandbox/providers/Microsoft.Authorization/policyAssignments/sandbox-org"
            ]
        }
    ],
```

Each entry in the array defines one of the environmnent types:
| Element | Description |
|---------|-------------|
| `environmentType` | Environment type to calculate. |
| `policyAssignments` | List of Policy assignment which are representative of an `environmentType` |

<br/>[Back to top](#definitions-and-global-settings)<br/>

### initiativeSetsToCompare

`initiativeSetsToCompare` is used by `Get-AzEffectsForInitiative.ps1` to calculate a spreadsheet containing the default effects for multiple Initiative definitions and parameter definitions representing the default values. These can be used to generate parameters for Policy Assignments.

```json
    "initiativeSetsToCompare": [
        {
            "setName": "NIST",
            "initiatives": [
                "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8", // Azure Security Benchmark v3
                "/providers/Microsoft.Authorization/policySetDefinitions/d5264498-16f4-418a-b659-fa7ef418175f", // FedRAMP High
                "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f", // NIST SP 800-53 Rev. 5
                "/providers/Microsoft.Authorization/policySetDefinitions/03055927-78bd-4236-86c0-f36125a10dc9" // NIST SP 800-171 Rev. 2
            ]
        },
        {
            "setName": "ASB",
            "initiatives": [
                "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8" // Azure Security Benchmark v3
            ]
        }
    ]
```

| Element | Description |
|---------|-------------|
| `setName` | Matches the script parameter `initiativeSetSelector`. |
| `initiatives` | List of Initiatives to compare |

<br/>[Back to top](#definitions-and-global-settings)<br/>

## Reading List

1. **[Pipeline](../Pipeline/README.md)**

1. **[Update Global Settings](#definitions-and-global-settings)**

1. **[Create Policy Definitions](../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../Definitions/Assignments/README.md)**

1. **[Scripts](../Scripts/README.md)**

**[Return to the main page](../README.md)**
<br/>[Back to top](#pipeline)<br/>
