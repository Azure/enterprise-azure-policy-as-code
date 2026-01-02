# Plan: Add Terraform-Style Diff Output to Policy Plans (FINAL IMPLEMENTATION PLAN)

**Summary:** Add precise, path-level diff output to Build-DeploymentPlans.ps1 with Terraform-style visualization using a single DiffGranularity parameter. Default to "summary" (current behavior) to maintain backward compatibility. Generate optional diff artifacts for tooling integration. Implement in a single branch/PR.

**Key Design Decisions:**
- Default `DiffGranularity = "summary"` preserves exact current behavior (zero breaking changes)
- Create NEW output functions (Write-ModernDiff family) - no modifications to existing Write-Modern* functions
- Plan file structure unchanged - diff arrays are additive properties only when granularity > summary
- Console output + optional JSON diff file for tooling
- No HTML reports, no PR automation, no breaking change detection (future enhancements)

## Implementation Steps

### 1. Add single DiffGranularity parameter with configuration precedence

Add `[ValidateSet("summary", "standard", "detailed", "verbose")] [string] $DiffGranularity = "summary"` to [Build-DeploymentPlans.ps1](Scripts/Deploy/Build-DeploymentPlans.ps1) after existing parameters; implement precedence: CLI parameter → `$env:EPAC_DIFF_GRANULARITY` → `global-settings.jsonc` `outputPreferences.diffGranularity` → default "summary"; when "summary", execute exactly current code path with zero diff computation; when standard/detailed/verbose, enable diff generation with levels: standard (property before/after), detailed (+metadata/arrays), verbose (+complete context).

### 2. Create new diff utility functions without modifying existing code

Add new helper functions in [Scripts/Helpers/](Scripts/Helpers/): `New-DiffEntry.ps1` (creates `@{op; path; before; after; classification}` objects), `ConvertTo-JsonPointer.ps1` (generates RFC 6902 paths), `Test-IsSensitivePath.ps1` (detects secrets/credentials/secureString for masking), `Export-PolicyDiffArtifact.ps1` (writes optional `policy-diff.json` to Output folder when `$DiffGranularity -ne "summary"`); create NEW output functions `Write-ModernDiff.ps1` and `Write-ModernDiffSummary.ps1` using existing `Get-OutputTheme` and `$global:epacInfoStream` patterns—do NOT modify existing [Write-ModernStatus](Scripts/Helpers/Write-ModernOutput.ps1#L220-L251) or [Write-ModernCountSummary](Scripts/Helpers/Write-ModernOutput.ps1#L255-L310).

### 3. Extend comparison functions to conditionally return diff objects

Modify [Confirm-ObjectValueEqualityDeep.ps1](Scripts/Helpers/Confirm-ObjectValueEqualityDeep.ps1), [Confirm-MetadataMatches.ps1](Scripts/Helpers/Confirm-MetadataMatches.ps1), [Confirm-ParametersDefinitionMatch.ps1](Scripts/Helpers/Confirm-ParametersDefinitionMatch.ps1), [Confirm-ParametersMatch.ps1](Scripts/Helpers/Confirm-ParametersMatch.ps1) to: accept `$GenerateDiff` boolean parameter (passed when `$DiffGranularity -ne "summary"`), maintain fast boolean-only return when `$GenerateDiff = $false`, return `@{match; incompatible; changePacOwnerId; diff=@()}` when `$GenerateDiff = $true` with JSON Pointer paths and before/after values, apply sensitive value masking via `Test-IsSensitivePath`.

### 4. Implement identity-based array diffing for PolicySets

Extend [Confirm-PolicySetDefinitionMatch.ps1](Scripts/Helpers/Confirm-PolicySetDefinitionMatch.ps1) to perform identity-based comparison of `policyDefinitions` array using `policyDefinitionId` as key (not array index), generate add/remove operations as `/policyDefinitions[policyDefId]` to avoid false positives from reordering, apply same `$GenerateDiff` conditional logic as other comparers, handle `policyDefinitionGroups` array similarly with `name` as identity key.

### 5. Update plan builders to attach diff arrays conditionally

Modify [Build-PolicyPlan.ps1](Scripts/Deploy/Build-PolicyPlan.ps1#L130-L200), [Build-PolicySetPlan.ps1](Scripts/Deploy/Build-PolicySetPlan.ps1#L200-L250), [Build-AssignmentPlan.ps1](Scripts/Deploy/Build-AssignmentPlan.ps1#L124-L260), [Build-ExemptionsPlan.ps1](Scripts/Deploy/Build-ExemptionsPlan.ps1#L947) to: receive `$DiffGranularity` parameter, set `$generateDiff = ($DiffGranularity -ne "summary")`, pass `$generateDiff` to all comparison functions, when `$generateDiff = $true`, attach `diff` arrays to resources in `update`/`replace` collections as additive property; format [Build-AssignmentIdentityChanges](Scripts/Helpers/Build-AssignmentIdentityChanges.ps1#L257-L277) output as diff entries for display consistency while preserving existing plan structure.

### 6. Add diff rendering after count summary in Build-DeploymentPlans

In [Build-DeploymentPlans.ps1](Scripts/Deploy/Build-DeploymentPlans.ps1) after existing [Write-ModernCountSummary](Scripts/Deploy/Build-DeploymentPlans.ps1#L449-L498) calls, add conditional block: when `$DiffGranularity -ne "summary"`, call new `Write-ModernDiff` function for each resource type with changes (passing plan collections and granularity level); generate enriched pipeline variables (`policyChangeSummary`, `policyChangeCount`, `roleChangeSummary`, `roleChangeCount`) alongside existing `deployPolicyChanges`/`deployRoleChanges` for both Azure DevOps (`##vso[task.setvariable]`) and GitLab formats; optionally call `Export-PolicyDiffArtifact` to write `policy-diff.json` to Output folder when tooling integration needed.

### 7. Add configuration schema and update documentation

Add `outputPreferences` object to [global-settings-schema.json](Schemas/global-settings-schema.json) with properties: `diffGranularity` (enum: summary/standard/detailed/verbose), `colorizedOutput` (boolean, default true); update [settings-global-setting-file.md](Docs/settings-global-setting-file.md) with outputPreferences examples; add new section "Terraform-Style Diff Output" to [operational-scripts-reference.md](Docs/operational-scripts-reference.md) documenting `-DiffGranularity` parameter with examples for each level and pipeline variable usage; update [Build-DeploymentPlans.ps1](Scripts/Deploy/Build-DeploymentPlans.ps1) inline help with parameter descriptions.

## Testing & Validation

### 1. Backward compatibility verification

With default `DiffGranularity = "summary"`, output and plan files must be byte-for-byte identical to current behavior; existing pipelines and downstream consumers must work without modification.

### 2. Unit tests for comparison functions

Test each modified Confirm-* function with `$GenerateDiff = $false` (boolean return) and `$GenerateDiff = $true` (diff object return); validate JSON Pointer path accuracy, before/after value capture, sensitive value masking, array identity-based diffing.

### 3. Integration tests for granularity levels

Test Build-DeploymentPlans.ps1 at each granularity level (summary/standard/detailed/verbose) with fixtures containing: new/update/replace/delete operations, parameter changes, metadata changes, array modifications, identity role assignment changes.

### 4. Performance testing

Confirm zero performance impact when `DiffGranularity = "summary"`; measure acceptable overhead for standard/detailed/verbose modes.

## Technical Details

### Diff Schema

Each diff entry contains:
- `op`: `add | remove | replace` (RFC 6902 style)
- `path`: JSON Pointer (e.g., `/parameters/maxAge/value`)
- `before`: Old value (null for add, redacted if sensitive)
- `after`: New value (null for remove, redacted if sensitive)
- `classification`: `parameter | metadata | policyRule | override | identity | resourceSelector | core`

### Granularity Levels

**summary** (default):
- Exactly current behavior
- Count-based changes only: "5 updates, 2 new, 1 delete"
- No diff computation overhead
- Example: `⭮ Update (display,param): Policy Name`

**standard**:
- Property-level changes with before/after values
- Terraform-style output with +/- indicators
- Omit unchanged nested objects
- Example:
  ```
  ⭮ Update: Policy Name
    ~ /displayName: "Old Name" → "New Name"
    ~ /parameters/maxAge/value: 90 → 120
  ```

**detailed**:
- All property changes including nested objects
- Array element-by-element comparison
- Metadata changes included
- Full context for troubleshooting

**verbose**:
- Complete before/after objects
- Include unchanged properties for context
- Full metadata and timestamps
- Maximum detail for debugging/compliance

### Pipeline Integration

**Enhanced Pipeline Variables:**
```powershell
# Existing (preserved)
deployPolicyChanges: yes/no
deployRoleChanges: yes/no

# New (added)
policyChangeSummary: "5 updates, 2 new, 1 delete"
policyChangeCount: 8
roleChangeSummary: "3 added, 1 removed"
roleChangeCount: 4
```

**Artifact Structure:**
```
Output/
  plans-{environment}/
    policy-plan.json         # Existing (unchanged when summary)
    roles-plan.json          # Existing (unchanged when summary)
    policy-diff.json         # NEW: Optional detailed diff (when granularity > summary)
```

### Sensitive Value Masking

Patterns detected as sensitive:
- Parameter type `secureString`
- Paths matching: `*secret*`, `*password*`, `*key*`, `*token*`, `*credential*`

Rendered as: `~ /path: (sensitive) changed` without literal values.

### Configuration Example

Add to `global-settings.jsonc`:
```jsonc
{
  "pacOwnerId": "...",
  "outputPreferences": {
    "diffGranularity": "standard",
    "colorizedOutput": true
  },
  "pacEnvironments": [...]
}
```

### Example Outputs

**Assignment with standard granularity:**
```
⭮ Update: guardrails (/providers/Microsoft.Management/managementGroups/mg-Enterprise)
  ~ /displayName: "Guardrails (Prod)" → "Guardrails (Enterprise)"
  ~ /parameters/maxAge/value: 90 → 120
  ~ /enforcementMode: "Default" → "DoNotEnforce"
  + /identity/roleAssignments/-: { principalId=..., role="Contributor" }
```

**Policy Set with detailed granularity:**
```
⭮ Update: enterprise-guardrails
  ~ /displayName: "Enterprise Guardrails v1" → "Enterprise Guardrails v2"
  ~ /metadata/version: "1.0.0" → "2.0.0"
  ~ /parameters/enforceTag/defaultValue: "false" → "true"
  + /policyDefinitions[denyPublicIP]
  - /policyDefinitions[requireTags]
```

## Implementation Notes

### Comparison Function Signature Changes

**Before:**
```powershell
function Confirm-MetadataMatches {
    param($ExistingMetadataObj, $DefinedMetadataObj)
    # Returns: $match, $changePacOwnerId
}
```

**After:**
```powershell
function Confirm-MetadataMatches {
    param(
        $ExistingMetadataObj,
        $DefinedMetadataObj,
        [bool] $GenerateDiff = $false
    )
    # Returns: @{ match = $bool; changePacOwnerId = $bool; diff = @(...) }
}
```

### Array Identity Diffing Example

**PolicySet policyDefinitions array:**
```powershell
# Old array (deployed)
@(
    @{ policyDefinitionId = "/providers/.../denyPublicIP"; ... },
    @{ policyDefinitionId = "/providers/.../requireTags"; ... }
)

# New array (defined)
@(
    @{ policyDefinitionId = "/providers/.../requireTags"; ... },
    @{ policyDefinitionId = "/providers/.../enforceEncryption"; ... }
)

# Generated diffs (identity-based, not index-based)
@(
    @{ op = "remove"; path = "/policyDefinitions[denyPublicIP]"; ... },
    @{ op = "add"; path = "/policyDefinitions[enforceEncryption]"; ... }
)
```

### Performance Optimization

**Fast path when DiffGranularity = "summary":**
```powershell
# In Build-DeploymentPlans.ps1
$generateDiff = ($DiffGranularity -ne "summary")

# Pass to plan builders
Build-PolicyPlan ... -GenerateDiff:$generateDiff

# In plan builders, pass to comparison functions
$metadataResult = Confirm-MetadataMatches -ExistingMetadataObj $existing `
    -DefinedMetadataObj $defined -GenerateDiff $generateDiff

if ($generateDiff) {
    # Use diff arrays
    $resource.diff = $metadataResult.diff + $parametersResult.diff + ...
} else {
    # Fast boolean path (current behavior)
    $match = $metadataResult.match -and $parametersResult.match
}
```

## Risk Mitigation

1. **Breaking changes**: Default to "summary" preserves exact current behavior
2. **Performance**: Zero overhead when summary mode; lazy evaluation for other modes
3. **Excessive output**: Path filters and granularity levels control verbosity
4. **Sensitive data**: Automatic masking with opt-out when safe
5. **Maintenance**: New functions isolated from existing code paths

## Success Criteria

- [ ] Default behavior identical to current (byte-for-byte output match)
- [ ] Terraform-style diffs render correctly at standard/detailed/verbose levels
- [ ] Sensitive values properly masked
- [ ] Array identity-based diffing works for PolicySets
- [ ] Pipeline variables enriched with change summaries
- [ ] Optional policy-diff.json generated for tooling
- [ ] Zero performance regression at summary level
- [ ] Documentation complete with examples
- [ ] Unit and integration tests passing

This plan is ready for implementation as a single branch/pull request.
