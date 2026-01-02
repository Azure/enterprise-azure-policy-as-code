# Terraform-Style Diff Output

The EPAC Build-DeploymentPlans script now supports Terraform-style diff output for visualizing changes at the property level before deployment. This feature provides detailed insights into what will change, helping teams review and validate policy updates with confidence.

## Overview

By default, Build-DeploymentPlans operates in "summary" mode, showing only count-based change summaries (e.g., "5 updates, 2 new"). With the new `DiffGranularity` parameter, you can enable detailed property-level diffs similar to Terraform's plan output.

## Configuration

### Parameter

```powershell
Build-DeploymentPlans.ps1 -DiffGranularity <level>
```

### Configuration Precedence

The diff granularity is determined in the following order:

1. **CLI Parameter** - Explicitly provided `-DiffGranularity` parameter
2. **Environment Variable** - `$env:EPAC_DIFF_GRANULARITY`
3. **Global Settings** - `outputPreferences.diffGranularity` in `global-settings.jsonc`
4. **Default** - `summary` (current behavior, no diff generation)

### Global Settings Configuration

Add to your `global-settings.jsonc`:

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

## Granularity Levels

### summary (default)

Preserves exact current behavior:
- Count-based changes only
- No diff computation overhead
- Zero breaking changes

```
⭮ Update (display,param): Policy Name
```

### standard

Property-level changes with before/after values:
- Terraform-style output with +/- indicators
- Omits unchanged nested objects
- Best for typical review workflows

```
⭮ Update: Policy Name
  ~ /displayName: "Old Name" → "New Name"
  ~ /parameters/maxAge/value: 90 → 120
```

### detailed

All property changes including nested objects:
- Array element-by-element comparison
- Metadata changes included
- Full context for troubleshooting

```
⭮ Update: enterprise-guardrails
  ~ /displayName: "Enterprise Guardrails v1" → "Enterprise Guardrails v2"
  ~ /metadata/version: "1.0.0" → "2.0.0"
  ~ /parameters/enforceTag/defaultValue: "false" → "true"
  + /policyDefinitions[denyPublicIP]
  - /policyDefinitions[requireTags]
```

### verbose

Complete before/after objects:
- Include unchanged properties for context
- Full metadata and timestamps
- Maximum detail for debugging/compliance

## Features

### Sensitive Value Masking

Sensitive values are automatically masked in diff output:

- Parameters with type `secureString` or `secureObject`
- Paths containing: `secret`, `password`, `key`, `token`, `credential`

Rendered as: `~ /path: (sensitive) changed`

### Identity-Based Array Diffing

Policy Set definitions use identity-based array comparison:

```
# Instead of index-based (prone to false positives):
~ /policyDefinitions[0]: changed
~ /policyDefinitions[1]: changed

# Identity-based (accurate):
+ /policyDefinitions[denyPublicIP]
- /policyDefinitions[requireTags]
```

### JSON Pointer Paths

All paths follow RFC 6902 JSON Pointer format:

```
/parameters/maxAge/value
/metadata/version
/policyDefinitions[policyDefId]/parameters/threshold/value
```

### Diff Artifact Export

When `DiffGranularity` is not "summary", an optional `policy-diff.json` artifact is created in the Output folder for CI/CD integration:

```
Output/
  plans-{environment}/
    policy-plan.json         # Existing
    roles-plan.json          # Existing
    policy-diff.json         # NEW: Detailed diff
```

### Enhanced Pipeline Variables

Additional pipeline variables are available for DevOps workflows:

**Azure DevOps:**
```yaml
- task: PowerShell@2
  name: buildPlans
  inputs:
    filePath: 'Scripts/Deploy/Build-DeploymentPlans.ps1'
    arguments: '-PacEnvironmentSelector prod -DiffGranularity standard'

# Use in conditions:
- ${{ if ne(variables['buildPlans.policyChangeCount'], '0') }}:
  - script: echo "Deploying $(buildPlans.policyChangeSummary)"
```

**Available Variables:**
- `policyChangeSummary`: "5 policy sets, 3 assignments"
- `policyChangeCount`: 8
- `roleChangeSummary`: "3 added, 1 removed"
- `roleChangeCount`: 4
- `deployPolicyChanges`: "yes" / "no" (existing)
- `deployRoleChanges`: "yes" / "no" (existing)

## Examples

### CLI Usage

```powershell
# Default behavior (no diff)
./Scripts/Deploy/Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod

# Standard diff output
./Scripts/Deploy/Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod -DiffGranularity standard

# Detailed diff with artifact export
./Scripts/Deploy/Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod -DiffGranularity detailed
```

### Environment Variable

```powershell
# Set for all builds
$env:EPAC_DIFF_GRANULARITY = "standard"
./Scripts/Deploy/Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod
```

### CI/CD Pipeline

**Azure DevOps:**

```yaml
steps:
  - task: PowerShell@2
    displayName: 'Build Deployment Plans'
    name: buildPlans
    inputs:
      filePath: 'Scripts/Deploy/Build-DeploymentPlans.ps1'
      arguments: >
        -PacEnvironmentSelector $(PacEnvironmentSelector)
        -DiffGranularity standard
        -DevOpsType ado

  - task: PowerShell@2
    displayName: 'Review Changes'
    condition: ne(variables['buildPlans.policyChangeCount'], '0')
    inputs:
      targetType: 'inline'
      script: |
        Write-Host "Policy changes detected: $(buildPlans.policyChangeSummary)"
        Write-Host "Role changes detected: $(buildPlans.roleChangeSummary)"
```

## Performance

- **Summary mode**: Zero overhead (default)
- **Standard mode**: Minimal overhead (~5-10% increase)
- **Detailed/Verbose**: Moderate overhead for large policy sets

## Backward Compatibility

The default `DiffGranularity = "summary"` ensures:
- Zero breaking changes
- Byte-for-byte identical output to previous versions
- Existing pipelines continue to work without modification

## Troubleshooting

### No diff output shown

Check that:
1. `DiffGranularity` is not "summary"
2. There are actual changes in the plan
3. Changes are in `update` collections (not `new` or `delete`)

### Diff artifact not created

Verify:
1. `DiffGranularity` is not "summary"
2. There are changes in either policies or roles
3. Output folder has write permissions

### Sensitive values exposed

If a sensitive value appears in diff output:
1. Check parameter type in policy definition
2. Add keyword to `Test-IsSensitivePath` patterns
3. Report issue for additional masking patterns

## Future Enhancements

Planned features include:
- HTML diff reports for pull requests
- Breaking change detection and warnings
- Diff filtering by resource type or scope
- Integration with approval workflows
