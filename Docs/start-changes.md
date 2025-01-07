# Changes in v10.0.0

> [!CAUTION]
> Read the **breaking changes** below carefully and adjust your environment accordingly.

## Breaking Changes in v10.0.0

### Changes in `globalSettings.jsonc`

> [!WARNING]
> We heavily reworked the `globalSettings.jsonc` file. You will need to update the file.

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

Field `desiredState.includeResourceGroups` is deprecated/removed. This change removes all Policy Assignments in resource groups not defined in the Policy Assignment definition files. To keep the previous behavior, add a pattern `"/subscriptions/*/resourceGroups/*" to the`"excludedScopes"` array.

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

## Enhancements in v10.0.0

### Support for Cloud environments with limited Support for Resource Graph Queries

- US Government Cloud handling of Role Assignments
- China cloud (21v) handling for Role Assignments and Exemptions.

### Cross-tenant (Lighthouse) support for Role Assignments

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

## Prerelease Features

- v10.7.6-alpha - Subscription pattern matching for excluded scopes in assignments
