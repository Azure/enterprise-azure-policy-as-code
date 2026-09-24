---
name: alz-sync-troubleshoot
description: Use when troubleshooting issues with the ALZ / AMBA / FSI / SLZ library sync process in EPAC (e.g. Sync-ALZPolicyFromLibrary or New-ALZPolicyDefaultStructure errors, unexpected generated assignment files, parameter or management group mapping problems). Sets up a minimal `Definitions` folder with a placeholder `global-settings.jsonc` and runs the two sync commands so the failure can be reproduced and inspected.
---

# ALZ Sync Troubleshooting Skill

This skill reproduces the ALZ Library sync workflow with a minimal scratch `Definitions` folder. Use it to investigate issues in `New-ALZPolicyDefaultStructure` and `Sync-ALZPolicyFromLibrary` (see `Docs/integrating-with-alz-library.md`).

It is intended for the GitHub Copilot cloud agent. Do **not** commit the generated `Definitions/`, `policyStructures/`, or `temp/` folders – they are scratch artefacts.

## When to use

Trigger this skill when the user reports problems such as:

- `New-ALZPolicyDefaultStructure` failing or producing an empty / malformed default file
- `Sync-ALZPolicyFromLibrary` throwing errors, missing parameters, or generating unexpected assignments
- Issues specific to a `-Tag`, `-LibraryPath`, or a `-Type` (`ALZ`, `AMBA`, `FSI`, `SLZ`)
- Differences between two ALZ Library tags
- AMBA extended policies sync (`-SyncAMBAExtendedPolicies`)

## Prerequisites

- PowerShell 7+
- `git` available on PATH (the scripts clone `Azure/Azure-Landing-Zones-Library`)
- Run from the repo root (`enterprise-azure-policy-as-code`). The scripts live in `Scripts/CloudAdoptionFramework/`.

## Steps

### 1. Create a minimal scratch Definitions folder

Create `./Definitions/global-settings.jsonc` with placeholder values – the sync commands only need a valid `pacEnvironments` entry whose `pacSelector` matches `-PacEnvironmentSelector` (default `epac-dev`).

```powershell
New-Item -ItemType Directory -Force -Path ./Definitions | Out-Null

@'
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json",
    "pacOwnerId": "00000000-0000-0000-0000-000000000000",
    "pacEnvironments": [
        {
            "pacSelector": "epac-dev",
            "cloud": "AzureCloud",
            "tenantId": "00000000-0000-0000-0000-000000000000",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/epac-troubleshoot",
            "desiredState": {
                "strategy": "ownedOnly"
            },
            "globalNotScopes": [],
            "managedIdentityLocation": "eastus2"
        }
    ]
}
'@ | Set-Content -Path ./Definitions/global-settings.jsonc -Encoding utf8
```

### 2. Run `New-ALZPolicyDefaultStructure`

This must run at least once before sync. It generates the policy structure file under `Definitions/policyStructures/`.

```powershell
./Scripts/CloudAdoptionFramework/New-ALZPolicyDefaultStructure.ps1 `
    -DefinitionsRootFolder ./Definitions `
    -Type ALZ `
    -PacEnvironmentSelector epac-dev
```

Useful variants when reproducing a bug report:

```powershell
# Pin to a specific library tag
-Tag "platform/alz/2025.02.0"

# Reuse an already-cloned/modified library (skips git clone)
-LibraryPath ./temp

# Other library types
-Type AMBA   # or FSI / SLZ
```

### 3. Run `Sync-ALZPolicyFromLibrary`

```powershell
./Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1 `
    -DefinitionsRootFolder ./Definitions `
    -Type ALZ `
    -PacEnvironmentSelector epac-dev
```

Useful switches when reproducing reported issues:

| Switch | Purpose |
| --- | --- |
| `-Tag <tag>` | Pin to a specific library release (e.g. `platform/alz/2025.02.0`). |
| `-LibraryPath <path>` | Use a pre-cloned / modified library; skip clone. |
| `-CreateGuardrailAssignments` | Reproduce guardrail-assignment generation issues. |
| `-EnableOverrides` | Reproduce override-related issues. |
| `-SyncAssignmentsOnly` | Only refresh assignments. |
| `-SyncAMBAExtendedPolicies` | AMBA-only; also clones `azure-monitor-baseline-alerts`. |

### 4. Inspect output

After the commands succeed, the relevant generated artefacts are:

- `Definitions/policyStructures/*.jsonc` – defaults file produced in step 2
- `Definitions/policyAssignments/<Type>/**` – assignments produced in step 3
- `Definitions/policyDefinitions/<Type>/**`, `Definitions/policySetDefinitions/<Type>/**` – synced definitions
- `temp/` (and `temp_amba_extended/` for AMBA extended) – cloned library; safe to delete

When troubleshooting, capture the full console output of both commands and any stack trace. Note the `-Tag` value printed in the header – sync errors are usually tied to a specific library release.

### 5. Cleanup

```powershell
Remove-Item -Recurse -Force ./Definitions, ./temp, ./temp_amba_extended -ErrorAction SilentlyContinue
```

## Notes

- Default tags live near the top of both scripts (`Scripts/CloudAdoptionFramework/*.ps1`) – check there if "latest" behaviour seems off.
- The scripts validate `-Tag` against `https://api.github.com/repos/Azure/Azure-Landing-Zones-Library/git/refs/tags/`; network egress to GitHub is required.
- Minimum EPAC module version supporting this flow is `10.9.0` (per `Docs/integrating-with-alz-library.md`).
