# Terraform-Style Diff Output

The EPAC Build-DeploymentPlans script supports Terraform-style diff output for visualizing changes at the property level before deployment. This feature provides detailed insights into what will change, helping teams review and validate policy updates with confidence.

## Overview

By default, Build-DeploymentPlans operates in "standard" mode, showing count-based change summaries (e.g., "5 updates, 2 new"). With the `DiffGranularity` parameter set to "detailed", you can enable detailed property-level diffs similar to Terraform's plan output.

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
4. **Default** - `standard` (count-based output, no property-level diff generation)

### Global Settings Configuration

Add to your `global-settings.jsonc`:

```jsonc
{
  "pacOwnerId": "...",
  "outputPreferences": {
    "diffGranularity": "detailed",
    "colorizedOutput": true
  },
  "pacEnvironments": [...]
}
```

## Granularity Levels

### standard (default)

Count-based change summaries:
- Count-based changes only
- No diff computation overhead
- Minimal output for quick overview

```
⭮ Update (display,param): Policy Name
```

### detailed

Property-level changes with before/after values:
- Terraform-style output with +/- indicators
- Omits unchanged nested objects
- Best for typical review workflows

### detailed

All property changes with full context:
- Terraform-style output with +/- indicators
- Array element-by-element comparison
- Metadata changes included
- Full context for troubleshooting and review

```
⭮ Update: enterprise-guardrails
  ~ /displayName: "Enterprise Guardrails v1" → "Enterprise Guardrails v2"
  ~ /metadata/version: "1.0.0" → "2.0.0"
  ~ /parameters/enforceTag/defaultValue: "false" → "true"
  + /policyDefinitions[denyPublicIP]
  - /policyDefinitions[requireTags]
```

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

When `DiffGranularity` is set to "detailed", an optional `policy-diff.json` artifact is created in the Output folder for CI/CD integration:

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
# Default behavior (count-based output)
./Scripts/Deploy/Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod

# Detailed diff with property-level changes and artifact export
./Scripts/Deploy/Build-DeploymentPlans.ps1 -PacEnvironmentSelector prod -DiffGranularity detailed
```

### Environment Variable

```powershell
# Set for detailed output on all builds
$env:EPAC_DIFF_GRANULARITY = "detailed"
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
        -DiffGranularity detailed
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
