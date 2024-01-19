# Definitions and Global Settings

## Folders

This `Definitions` folder and subfolders contains all your definitions. The `Sync-Repo.ps1` script does not copy this folder.

1. Define the Azure environment(s) in file **[global-settings.jsonc](#global-settings)**
1. Create custom Policies (optional) in folder **[policyDefinitions](policy-definitions.md)**
1. Create custom Policy Sets (optional) in folder **[policySetDefinitions](policy-set-definitions.md)**
1. Define the Policy Assignments in folder **[policyAssignments](policy-assignments.md)**
1. Define the Policy Exemptions (optional) in folder **[policyExemptions](policy-exemptions.md)**
1. Define Documentation in folder **[policyDocumentations](documenting-assignments-and-policy-sets.md)**

## Global Settings

`global-settings.jsonc` has following sections explained below:

- `telemetryOptOut` if set to true disables the collection of usage date for the EPAC repo. The default is false. See [Usage Tracking](usage-tracking.md) for more information.
- `pacOwnerId` uniquely identifies deployments from a specific repo. We recommend using a GUID.
- `pacEnvironments` defines the EPAC environments.
- `managedIdentityLocations` is used in Policy Assignments as the location of the created Managed Identities.
- `globalNotScopes` defines scopes not subject to the Policy Assignments.

### JSON Schema

The GitHub repo contains a JSON schema which can be used in tools such as [VS Code](https://code.visualstudio.com/Docs/languages/json#_json-schemas-and-settings) to provide code completion.

To utilize the schema add a ```$schema``` tag to the JSON file.

```
{
  "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
}
```

This schema is new in v7.4.x and may not be complete. Please let us know if we missed anything.

### Opt out of telemetry data collection `telemetryOptOut`

Starting with v8.0.0, Enterprise Policy as Code (EPAC) is tracking the usage using Customer Usage Attribution (PID). See [Usage Tracking](usage-tracking.md) for more information on opt out. Default is false.

```json
"telemetryOptOut": true,
```

### Uniquely identify deployments `pacOwnerId`

`pacOwnerId` is required for [desired state handling](desired-state-strategy.md) to distinguish Policy resources deployed via this EPAC repo, legacy technology, another EPAC repo, or another Policy as Code solution.

### Define EPAC Environments in `pacEnvironments`

EPAC has a concept of an environment identified by a string (unique per repository) called `pacSelector` as defined in `pacEnvironments`. An environment associates the following with the `pacSelector`:

- `cloud` - to select sovereign cloud environments.
- `tenantId` - enables multi-tenant scenarios.
- `rootDefinitionScope` - the deployment scope for the Policies and Policy Sets to be used in assignments later.
  - Policy Assignments can only defined at this scope and child scopes (recursive).
  - Operational tasks, such as `Create-AzRemediationTasks.ps1`, must use the same `rootDefinitionScope` or they will fail.
- Optional: define `desiredState` strategy. This element is documented in two places:
  - [Desired State Strategy](desired-state-strategy.md). and 
  - [Managing Defender for Cloud Assignments](dfc-assignments.md).

Like any other software or IaC solution, EPAC needs areas for developing and testing new Policies, Policy Sets and Policy Assignments before any deployment to EPAC prod environments. In most cases you will need one management group hierarchy to simulate EPAC production management groups for development and testing of Policies. EPAC's prod environment will govern all other IaC environments (e.g., sandbox, development, integration, test/qa, pre-prod, prod, ...) and tenants. This can be confusing. We will use EPAC environment(s) and IaC environments to disambiguate the environments.

In a centralized single tenant scenario, you will define two EPAC environments: epac-dev and tenant. In a multi-tenant scenario, you will add an additional EPAC environment per additional tenant.

The `pacSelector` is just a name. We highly recommend to call the Policy development environment `epac-dev`, you can name the EPAC prod environments in a way which makes sense to you in your environment. We use `tenant`, `tenant1`, etc in our samples and documentation. These names are used and therefore must match:

- Defining the association (`pacEnvironments`) of an EPAC environment, `managedIdentityLocation` and `globalNotScopes` in `global-settings.jsonc`
- Script parameter when executing different deployment stages in a CI/CD pipeline or semi-automated deployment targeting a specific EPAC environments.
- `scopes`, `notScopes`, `additionalRoleAssignments`, `managedIdentityLocations`, and `userAssignedIdentity` definitions in Policy Assignment JSON files.

```json
"pacEnvironments": [
    {
        "pacSelector": "epac-dev",
        "cloud": "AzureCloud",
        "tenantId": "70238025-b3dc-40a5-bea1-314973cea2db",
        "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/PAC-Heinrich-Dev"
    },
    {
        "pacSelector": "tenant",
        "cloud": "AzureCloud",
        "tenantId": "70238025-b3dc-40a5-bea1-314973cea2db",
        "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/Contoso-Root",
        "inheritedDefinitionsScopes": [], // optional for desired state coexistence scenarios
        "desiredState": { // optional for desired state coexistence scenarios
        }
    }
],
```

### DeployIfNotExists and Modify Policy Assignments need `managedIdentityLocation`

Policies with `Modify` and `DeployIfNotExists` effects require a Managed Identity for the remediation task. This section defines the location of the managed identity. It is often created in the tenant's primary location. This location can be overridden in the Policy Assignment files. The star in the example matches all `pacEnvironmentSelector` values.

```json
    "managedIdentityLocation": {
        "*": "eastus2"
    },
```

### Excluding scopes for all Assignments with `globalNotScopes`

Resource Group patterns allow us to exclude "special" managed Resource Groups. The exclusion is not dynamic. It is calculated when the deployment scripts execute.

The arrays can have the following entries:

| Scope type | Example |
|------------|---------|
| `managementGroups` | "/providers/Microsoft.Management/managementGroups/myManagementGroupId" |
| `subscriptions` | "/subscriptions/00000000-0000-0000-000000000000" |
| `resourceGroups` | "/subscriptions/00000000-0000-0000-000000000000/resourceGroups/myResourceGroup" |
| `resourceGroupPatterns` | No wild card or single \* wild card at beginning or end of name or both; wild cards in the middle are invalid: <br/> "/resourceGroupPatterns/name" <br/> "/resourceGroupPatterns/name\*" <br/>  "/resourceGroupPatterns/\*name" <br/> "/resourceGroupPatterns/\*name\*"<br/>

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
