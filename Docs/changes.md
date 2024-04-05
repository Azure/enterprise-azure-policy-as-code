# Changes in v10.0.0

!!! danger "Caution"

    Read the [breaking changes](#breaking-changes-in-v1000) carefully and adjust your environment accordingly.

## Breaking Changes in v10.0.0

### Changes in `globalSettings.jsonc`

!!! warning

    We heavily reworked the `globalSettings.jsonc` file. You will need to update the file.

Deprecated top-level elements:

- `globalNotScopes` is moved as an array into each `pacEnvironment`. If you used the `*` notation, copy the array into each `pacEnvironment`.
- `managedIdentityLocations` is moved as a string into each `pacEnvironment`. If you used the `*` notation, copy the string into each `pacEnvironment`.

Per `pacEnvironment`:

- New required `managedIdentityLocation` string.
- New optional `globalNotScopes` array.
- New optional `deployedBy` string. We recommend against using it and let EPAC [generate the default value](#metadata-deployedby-and-assignedby).
- `inheritedDefinitionsScopes` has been deprecated and removed. Please review the revised use case [Use Case 4:  Multiple Teams in a Hierarchical Organization](settings-desired-state.md#use-case-4-multiple-teams-in-a-hierarchical-organization).
- `cloud` is now a required field. Previously, it was optional and defaulted to `AzureCloud`.
- `desiredState` is now a required field.

`desiredState` has newly required fields:

- `strategy`: was optional and defaulted to `full`. We recommend setting it to `full`, except during a short transition period to EPAC. This was changed to require an explicit decision.
- `keepDfcSecurityAssignments`: replaces `deleteDfcSecurityAssignments`  which defaulted to `true`. We highly recommend setting it to `false` and assigning any desired Initiative at management groups.

`desiredState` fields `deleteExpiredExemptions` and `deleteOrphanedExemptions` are deprecated and removed. Exemptions with an ``unknownOwner` are only deleted when `strategy` is `full`. 

The recommended `desiredState` settings are now as follows:

```json
"desiredState": {
    "strategy": "full",
    "keepDfcSecurityAssignments": false
}
```

During a brief transition from a pre-EPAC to an EPAC usage, you can set `desiredState` to `ownedOnly` to keep existing Policy resources. This is not recommended for long-term use.

```json
"desiredState": {
    "strategy": "ownedOnly",
    "keepDfcSecurityAssignments": false
}
```

### Desired State Handling for Policy Assignments

Field `desiredState.includeResourceGroups` is deprecated/removed. This change removes all Policy Assignments in resource groups not defined in the Policy Assignment definition files. To keep the previous behavior, add a pattern `"/subscriptions/*/resourceGroups/*" to the `"excludedScopes"` array.

Desired state handling for Policy Assignments related to Defender for Cloud (DfC) automatic Policy Assignments has been reworked. DfC creates two different types of Policy Assignments at the subscription level.

- Security and Compliance Initiatives, such as, Microsoft cloud security benchmark, NIST SP 800-53, ... EPAC calls them DfC Security Policy Assignments. The PAC owner is listed as `managedByDfcSecurityPolicies`
- Initiatives assigned by DfC when enrolling a subscription in a DfC workload protection plan. These assignments contain Policies required by DfC for finding vulnerabilities and threats. EPAC calls them DfC Defender Plan Policy Assignments. The PAC owner is listed as `managedByDfcDefenderPlans`.

Previously, the `desiredState.deleteDfcSecurityAssignments` field (default `true`) and was used to control the deletion of DfC both types of auto-assigned Policy Assignments at the subscription level when the `desiredState.strategy` was `"full"`. The new field is `keepDfcSecurityAssignments`.

- This behavior is now independent of the `desiredState.strategy` field. Therefore it will  delete DfC Security Policy Assignments at the subscription level, unless `desiredState.keepDfcSecurityAssignments` is set to `true`.
- Assignments created by DfC when enrolling a subscription in a DfC workload protection plan are **never** deleted starting with v10.0.0

### Build-PolicyDocumentation.ps1 ignores Policies with effect `Manual`

- `Build-PolicyDocumentation.ps1` skips Policies with effect `Manual`. Using the switch parameter `-IncludeManualPolicies` overrides this behavior reverting to the previous behavior.

### Deprecated Operational Scripts

EPAC had multiple operational scripts which are not Policy as Code related. These scripts are now deprecated and will be removed in a future release. The scripts have been moved to a new folder `Scripts-Deprecated` and are not included in the PowerShell module. The scripts are:

- `Get-AzMissingTags.ps1`
- `Get-AzResourceTags.ps1`
- `Get-AzStorageNetworkConfig.ps1`
- `Get-AzUserRoleAssignments.ps1`

We recommend that you use [Azure Governance Visualizer (AzGovViz)](https://github.com/JulianHayward/Azure-MG-Sub-Governance-Reporting) for these tasks.

## Enhancements planned for v10.1.0

- Script to update CSV effect/parameter files preserving extra columns: https://github.com/Azure/enterprise-azure-policy-as-code/issues/498.
- Automatically disable deprecated Policies: https://github.com/Azure/enterprise-azure-policy-as-code/issues/516.
- Cleanup/Improve `Export-PolicyResources` and `Build-PolicyDocumentation` scripts: https://github.com/Azure/enterprise-azure-policy-as-code/issues/517 and https://github.com/Azure/enterprise-azure-policy-as-code/issues/498.
- Simplify exemption creation by allowing lists of scopes and Policy definitions: https://github.com/Azure/enterprise-azure-policy-as-code/issues/518.
- Clarify SPNs, Least Privilege, and environments for CI/CD: https://github.com/Azure/enterprise-azure-policy-as-code/issues/519.

## Enhancements in v10.0.0

### Support for Cloud environments with limited Support for Resource Graph Queries

- US Government Cloud handling of Role Assignments
- China cloud (21v) handling for Role Assignments and Exemptions.

### Cross-tenant (Lighthouse) support for Role Assignments.

Cross-tenant Role Assignments are now supported. This is used if log collection is directed to a resource (Log Analytics, Event Hub. Storage) in a management tenant (e.g, Azure Lighthouse, and similar constructs) which requires you to use `additionalRoleAssignments` in the Policy Assignment file.

### Simplified Exemption definitions

Exemptions can be specified with a `policyDefinitionName` or `policyDefinitionId` instead of a `policyAssignmentId` and `policyDefinitionReferenceId`. EPAC creates as many Exemptions as needed to cover all Policy Assignments occurrences of the specified Policy
- Support for Microsoft release flow in addition to GitHub flow (documentation and starter kit)
- Schema updated to latest draft specification

### Description field in Role Assignments

The `description` field in Role Assignments is now populated with the Policy Assignment Id, reason and `deployedBy` value. This is useful for tracking the source of the Role Assignment.

Reasons is one of:

- `Role Assignment required by Policy` - Policy definition(s) specify the required Role Definition Ids.
- `additional Role Assignment` - from filed "additionalRoleAssignments" in the Policy Assignment file.
- `additional cross tenant Role Assignment` - from filed "additionalRoleAssignments" with `crossTenant` set to `$true` in the Policy Assignment file.

### Metadata `deployedBy` and `assignedBy`

`deployedBy` is a new field in the global settings per pacEnvironment. It is used to populate the `metadata` fields in the deployed resources.

If not defined in global settings, EPAC generates it as `"epac/{{pacOwnerId}}/{{pacSelector}}"`. You can override this value in the Policy resource file by entering it directly to the respective `metadata` field. It is added to the deployed resources as follows:

- Policy Definitions, Policy Set Definitions and Policy Exemptions - `metadata.deployedBy`.
- Policy Assignments - `metadata.assignedBy` since Azure Portal displays it as 'Assigned by'.
- Role Assignments - add the value to the [`description` field](#description-field-in-role-assignments).

### Schema Updates

Updating JSON schema to the latest [specification 2020-12](https://json-schema.org/specification).

### Documentation Updates

Reorganized the documentation to make it easier to find information. Added a new section on how to use the starter kit and how to use the Microsoft release flow.

### Code Cleanup

Ongoing cleanup of code: Removed unused code and improved code quality.

### Performance

Multiple lengthy sections of the code have been converted to parallel execution to improve performance. The change maybe ineffective if you limit the CI/CD agent to a single vCore or use the Azure DevOps provided CI/CD agents.

The scripts `Build-DeploymentPlan`, `Deploy-PolicyPlan`, and `Build-PolicyDocumentation` have a new parameter `VirtualCores` to control the number of parallel threads and allowing you to optimize your performance. The code applies the following formula to adjust the `For-Each -Parallel` throttle limits (threads) based on the number of VirtualCores.

- Threads = 1 x VirtualCores for pre-processing (pure compute) Policy and Policy Set parameters during Policy Assignment plan calculations
- Threads = 2 x VirtualCores for Policy object deployment since it executes many REST calls to the Azure resource manager and therefore spends much of its time waiting on I/O. 
- Threads = 4 (fixed) for reading and processing Policy resources; one each for
  - Policy definitions
  - Policy Set definitions
  - Policy Assignments, Role Assignments, and Role Definitions
  - Policy Exemptions

Setting VirtualCores to zero (0) disables parallel processing. The default value is 4. EPAC also uses a minimum chunk size for deployments to avoid unnecessary overhead for small number of items.

