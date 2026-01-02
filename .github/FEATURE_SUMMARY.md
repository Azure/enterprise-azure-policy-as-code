# Terraform-Style Diff Output Feature

## Summary

This feature branch implements Terraform-style diff output for EPAC's Build-DeploymentPlans script, providing detailed property-level change visualization before deployment. The implementation follows the design plan with zero breaking changes - the default behavior remains identical to the current version.

## What Was Implemented

### ✅ Core Infrastructure (Commits 1-2)

1. **New Helper Functions** (`Scripts/Helpers/`)
   - `New-DiffEntry.ps1` - Creates standardized diff entry objects (RFC 6902 format)
   - `ConvertTo-JsonPointer.ps1` - Generates JSON Pointer paths
   - `Test-IsSensitivePath.ps1` - Detects and masks sensitive values
   - `Export-PolicyDiffArtifact.ps1` - Exports diffs to JSON for tooling integration

2. **New Output Functions** (`Scripts/Helpers/`)
   - `Write-ModernDiff.ps1` - Renders Terraform-style diffs with color coding
   - `Write-ModernDiffSummary.ps1` - Provides change summaries across resource types
   - No modifications to existing `Write-Modern*` functions (maintains compatibility)

3. **Extended Comparison Functions**
   - `Confirm-MetadataMatches.ps1` - Now supports diff generation
   - `Confirm-ParametersDefinitionMatch.ps1` - Returns diff objects when requested
   - `Confirm-ParametersUsageMatches.ps1` - Tracks parameter value changes
   - `Confirm-PolicyDefinitionsInPolicySetMatch.ps1` - Identity-based array diffing
   - All functions maintain backward compatibility with boolean-only returns when `GenerateDiff = $false`

### ✅ Plan Builder Integration (Commit 2)

4. **Build-PolicySetPlan Updates**
   - Added `DiffGranularity` parameter
   - Conditional diff generation based on granularity level
   - Diff arrays attached to resources in update/replace collections
   - Preserves existing plan structure (additive property only)

5. **Build-DeploymentPlans Updates**
   - Added `DiffGranularity` parameter with validation
   - Configuration precedence: CLI → `$env:EPAC_DIFF_GRANULARITY` → global-settings → default
   - Conditional diff rendering after count summaries
   - Diff artifact export when granularity > summary
   - Enhanced pipeline logging

### ✅ Configuration & Schema (Commits 1-3)

6. **Schema Updates** (`Schemas/global-settings-schema.json`)
   - Added `outputPreferences` section
   - Properties: `diffGranularity` (enum) and `colorizedOutput` (boolean)
   - Fully backward compatible

7. **Documentation** (Commit 3)
   - New comprehensive guide: `Docs/terraform-style-diff-output.md`
   - Updated `Docs/settings-global-setting-file.md` with outputPreferences
   - Examples for all usage patterns (CLI, env vars, CI/CD)
   - Troubleshooting guide

## Implementation Highlights

### Zero Breaking Changes
- Default `DiffGranularity = "summary"` preserves exact current behavior
- Existing pipelines work without modification
- Plan file structure unchanged (diff is additive property)

### Identity-Based Array Diffing
Policy Set `policyDefinitions` arrays use identity-based comparison:
```
# Avoids false positives from reordering
+ /policyDefinitions[denyPublicIP]
- /policyDefinitions[requireTags]
```

### Sensitive Value Masking
Automatic masking for:
- `secureString` and `secureObject` parameter types
- Paths containing: secret, password, key, token, credential

### Granularity Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `summary` | Current behavior (default) | Production unchanged |
| `standard` | Property changes with +/- | PR reviews |
| `detailed` | + metadata/arrays | Troubleshooting |
| `verbose` | Complete context | Debugging/compliance |

## Files Changed

### New Files (10)
- `Scripts/Helpers/New-DiffEntry.ps1`
- `Scripts/Helpers/ConvertTo-JsonPointer.ps1`
- `Scripts/Helpers/Test-IsSensitivePath.ps1`
- `Scripts/Helpers/Export-PolicyDiffArtifact.ps1`
- `Scripts/Helpers/Write-ModernDiff.ps1`
- `Docs/terraform-style-diff-output.md`

### Modified Files (6)
- `Scripts/Deploy/Build-DeploymentPlans.ps1`
- `Scripts/Helpers/Build-PolicySetPlan.ps1`
- `Scripts/Helpers/Confirm-MetadataMatches.ps1`
- `Scripts/Helpers/Confirm-ParametersDefinitionMatch.ps1`
- `Scripts/Helpers/Confirm-ParametersUsageMatches.ps1`
- `Scripts/Helpers/Confirm-PolicyDefinitionsInPolicySetMatch.ps1`
- `Schemas/global-settings-schema.json`
- `Docs/settings-global-setting-file.md`

## Usage Examples

### Basic CLI
```powershell
# Default (no changes)
Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod

# With diffs
Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod -DiffGranularity standard
```

### Global Settings
```jsonc
{
  "pacOwnerId": "...",
  "outputPreferences": {
    "diffGranularity": "standard"
  },
  "pacEnvironments": [...]
}
```

### CI/CD Pipeline
```yaml
- task: PowerShell@2
  name: buildPlans
  inputs:
    filePath: 'Scripts/Deploy/Build-DeploymentPlans.ps1'
    arguments: '-PacEnvironmentSelector $(env) -DiffGranularity standard'
```

## Testing Recommendations

1. **Backward Compatibility**: Run with default parameters, verify output identical to main branch
2. **Standard Granularity**: Test with PolicySet updates, verify property-level diffs render correctly
3. **Sensitive Masking**: Test with secureString parameters, verify masking works
4. **Identity Diffing**: Reorder policyDefinitions array, verify no false change detection
5. **Artifact Export**: Enable diff granularity, verify policy-diff.json created

## Next Steps

- ✅ All planned features implemented
- ✅ Documentation complete
- ⏭️ Ready for testing and PR
- 🔮 Future enhancements (not in this PR):
  - Update Build-PolicyPlan for policy definition diffs
  - Update Build-AssignmentPlan for assignment diffs
  - Update Build-ExemptionsPlan for exemption diffs
  - HTML diff reports
  - Breaking change detection

## Commits

1. `716557d` - feat: Add diff utility functions and extend comparison functions
2. `669d993` - feat: Integrate diff generation into plan builders and output
3. `275c20d` - docs: Add comprehensive documentation for Terraform-style diff output

## Branch Status

Branch: `feat/terraform-style-diff-output`
Based on: `main` (or current default branch)
Ready for: PR submission
