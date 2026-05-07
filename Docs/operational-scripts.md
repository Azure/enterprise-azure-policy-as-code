# Operational Scripts

The scripts are detailed in the [reference page](operational-scripts-reference.md) including  syntax, descriptions and parameters.

## Batch Creation of Remediation Tasks

The script `New-AzRemediationTasks` creates remediation tasks for all non-compliant resources for EPAC environments in the `global-settings.jsonc` file.

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The script will recurse the Management Group structure and subscriptions from the defined starting point.

* Find all Policy assignments with potential remediation capable resources
* Query Policy Insights for non-complaint resources
* Start remediation task for each Policy with non-compliant resources
* Switch parameter `-OnlyCheckManagedAssignments` includes non-compliance data only for Policy assignments owned by this Policy as Code repo.
* Switch parameter `-OnlyDefaultEnforcementMode` to only run remediation tasks against policy assignments that have enforcement mode set to 'Default'"\.

#### Links

* [Guidance: Implementing an Azure Policy Based Remediation Solution](./guidance-remediation.md)
* [Remediate non-compliant resources with Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal)
* [Start-AzPolicyRemediation](https://learn.microsoft.com/en-us/powershell/module/az.policyinsights/start-azpolicyremediation?view=azps-10.1.0)

## Documenting Policy

`Build-PolicyDocumentation` builds documentation from instructions in the `policyDocumentations` folder reading the deployed Policy Resources from the EPAC environment. It is also used to generate parameter/effect CSV files for Policy Assignment files. See usage documentation in [Documenting Policy](operational-scripts-documenting-policy.md).

## Policy Resources Exports

<div style="margin: 30px 0; position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%; height: auto;">
  <iframe src="https://www.youtube.com/embed/--I-hPQfLvo" 
          style="position: absolute; top:0; left:0; width:100%; height:100%;" 
          frameborder="0" 
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
          allowfullscreen>
  </iframe>
</div>

* `Export-AzPolicyResources` exports Azure Policy resources in EPAC. See usage documentation in [Extract existing Policy Resources](start-extracting-policy-resources.md).
* `Get-AzExemptions` retrieves Policy Exemptions from an EPAC environment and saves them to files.
* `Get-AzPolicyAliasOutputCSV` exports Policy Aliases to CSV format.

## Hydration Kit

The Hydration Kit is a set of scripts that can be used to deploy an EPAC environment from scratch. The scripts are documented in the [Hydration Kit](operational-scripts-hydration-kit.md) page.

## CI/CD Helpers

The scripts `New-AzureDevOpsBug` and `New-GitHubIssue` create a Bug or Issue when there are one or multiple failed Remediation Tasks.

## Export Policy To EPAC

The script `Export-PolicyToEPAC.ps1` creates for you the policyAssignments, policyDefinitions, and policySetDefinitions based on the provided definition/set ID into an Output folder under 'Export'.

Parameters:

* **PolicyDefinitionId**: Mandatory url of the policy or policy set from AzAdvertizer.

* **PolicySetDefinitionId**: Mandatory url of the policy or policy set from AzAdvertizer.

* **ALZPolicyDefinitionId**: Mandatory url of the policy or policy set from AzAdvertizer.

* **ALZPolicySetDefinitionId**: Mandatory url of the policy or policy set from AzAdvertizer.

* **OutputFolder**: Output Folder. Defaults to the path 'Output'.

* **AutoCreateParameters**: Automatically create parameters for Azure Policy Sets and Assignment Files.

* **UseBuiltIn**: Default to using builtin policies rather than local versions.

* **PacSelector**: Used to set PacEnvironment for each assignment file based on the pac selector provided. This pulls from global-settings.jsonc, therefore it must exist or an error will be thrown.

* **OverwriteScope**: Used to overwrite scope value on each assignment file.

* **OverwritePacSelector**: Used to overwrite PacEnvironment for each assignment file.

* **OverwriteOutput**: Used to Overwrite the contents of the output folder with each run. Helpful when running consecutively.

## Non-compliance Reports

`Export-NonComplianceReports` exports non-compliance reports for EPAC environments . It outputs the reports in the `$OutputFolders/non-compliance-reports` folder.

* `summary-by-policy.csv` contains the summary of the non-compliant resources by Policy definition. The columns contain the resource counts.
* `summary-by-resource.csv` contains the summary of the non-compliant resources. The columns contain the number of Policies causing the non-compliance.
* `details-by-policy.csv` contains the details of the non-compliant resources by Policy definition including the non-compliant resource ids. Assignments are combined by Policy definition.
* `details-by-resource.csv` contains the details of the non-compliant resources sorted by Resource id. Assignments are combined by Resource id.
* `full-details-by-assignment.csv` contains the details of the non-compliant resources sorted by Policy Assignment id.
* `full-details-by-resource.csv` contains the details of the non-compliant resources sorted by Resource id including the Policy Assignment details.

### Sample `summary-by-policy.csv`

| Category | Policy Name | Policy Id | Non Compliant | Unknown | Not Started | Exempt | Conflicting | Error | Assignment Ids | Group Names |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| General | Audit usage of custom RBAC roles | /providers/microsoft.authorization/policydefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5 | 9 | 0 | 0 | 0 | 0 | 0 | /providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-nist-800-53-r5,/providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-asb | azure_security_benchmark_v3.0_pa-7,nist_sp_800-53_r5_ac-6(7),nist_sp_800-53_r5_ac-2(7),nist_sp_800-53_r5_ac-6,nist_sp_800-53_r5_ac-2 |
| Regulatory Compliance | Control use of portable storage devices | /providers/microsoft.authorization/policydefinitions/0a8a1a7d-16d3-4d8e-9f2c-6b8d9e1c7c1d | 0 | 0 | 0 | 0 | 0 | 0 | /providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-nist-800-53-r5,/providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-asb | azure_security_benchmark_v3.0_pa-7,nist_sp_800-53_r5_ac-6(7),nist_sp_800-53_r5_ac-2(7),nist_sp_800-53_r5_ac-6,nist_sp_800-53_r5_ac-2 |

### Sample `summary-by-resource.csv`

| Resource Id | Subscription Id | Subscription Name | Resource Group | Resource Type | Resource Name | Resource Qualifier | Non Compliant | Unknown | Not Started | Exempt | Conflicting | Error |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| /subscriptions/******************************** | ******************************** | PAC-DEV-001 |  | subscriptions |  |  | 25 | 481 | 0 | 0 | 0 | 0 |
| /subscriptions/********************************/providers/microsoft.authorization/roledefinitions/0b00bc79-2207-410c-b9d5-d5d182ad514f | ******************************** | PAC-DEV-001 |  | microsoft.authorization/roledefinitions | 0b00bc79-2207-410c-b9d5-d5d182ad514f |  | 0 | 0 | 0 | 0 | 0 | 0 |

## Bulk Edit Assignment Scopes

The script `Update-AssignmentScope.ps1` (in `Scripts/Helpers`) edits the `scope` (or `notScopes`) block of one or more policy assignment files in `Definitions/policyAssignments`. It supports nested `children[]` and walks the entire node tree of each file, applying the change to every node that matches the optional filters.

### Actions

| Action | Behavior | Required parameters |
| --- | --- | --- |
| `Append` | Adds the supplied path(s) to the existing `<selector>` array, deduping. Creates the selector if it doesn't exist. | `-Values` |
| `Set` | Overwrites the entire `<selector>` array with the supplied values. Creates the selector if it doesn't exist. | `-Values` |
| `Delete` | Removes the entire `<selector>` key from the block. | none |

### Parameters

| Parameter | Description |
| --- | --- |
| `-Path` | Optional. File or folder. When omitted, defaults to `<repo>/Definitions/policyAssignments` and recurses automatically. When an explicit folder is supplied, pass `-Recurse` to descend into subfolders. |
| `-Scope` | Selector name inside the assignment file's `scope` block (e.g. `TenantRootGroup`, `NonProd`, `EPAC-Prod`). Mutually exclusive with `-NotScopes`. |
| `-NotScopes` | Selector name inside the assignment file's `notScopes` block. Mutually exclusive with `-Scope`. |
| `-Action` | Required. `Append` \| `Set` \| `Delete`. |
| `-Values` | One or more resource paths (management group, subscription, or resource group). Required for `Append` and `Set`; ignored for `Delete`. |
| `-NodeName` | Optional filter. Only edit nodes whose `nodeName` property equals this value. |
| `-AssignmentName` | Optional filter. Only edit nodes whose `assignment.name` property equals this value. |
| `-Recurse` | When `-Path` is an explicitly supplied folder, descend into subfolders. |
| `-Backup` | Write a `*.bak` copy beside each modified file before saving. |
| `-WhatIf` / `-Confirm` | Standard PowerShell `ShouldProcess` switches for previewing changes. |

### Examples

Add a new selector to every assignment file in `Definitions/policyAssignments` (recursive):

```powershell
.\Scripts\Operations\Update-AssignmentScope.ps1 `
    -Scope NonProd -Action Append `
    -Values "/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000000"
```

Overwrite the `TenantRootGroup` selector on a single nested node:

```powershell
.\Scripts\Operations\Update-AssignmentScope.ps1 `
    -Path .\Definitions\policyAssignments\RestrictPublicAccess-Assignment-20260423.jsonc `
    -NodeName "TenantRootGroup/" `
    -Scope TenantRootGroup -Action Set `
    -Values @(
        "/providers/Microsoft.Management/managementGroups/68b133a0-68af-43fa-a9c3-d1b9bf296ea5",
        "/providers/Microsoft.Management/managementGroups/68b133a0-68af-43fa-a9c3-d1b9bf296ea7"
    )
```

Remove a selector from every node in every file under a folder, with backups:

```powershell
.\Scripts\Operations\Update-AssignmentScope.ps1 `
    -Path .\Definitions\policyAssignments -Recurse `
    -Scope NonProd -Action Delete -Backup
```

Append to the `TenantRootGroup` selector inside the `notScopes` block:

```powershell
.\Scripts\Operations\Update-AssignmentScope.ps1 `
    -NotScopes TenantRootGroup -Action Append `
    -Values "/subscriptions/00000000-0000-0000-0000-000000000000"
```

Preview changes without writing:

```powershell
.\Scripts\Operations\Update-AssignmentScope.ps1 -Scope NonProd -Action Delete -WhatIf
```

### Notes

* Comments in JSONC files are stripped on save. The script warns when it detects `//` or `/* */` comments before writing. Use `-Backup` (or rely on git) to recover the originals.
* Output is standard JSON. Existing formatting (single-line arrays, trailing commas) will be normalized on save. The result remains valid input for EPAC and conforms to `Schemas/policy-assignment-schema.json`.
* Filters are AND-combined. Omit both `-NodeName` and `-AssignmentName` to apply to every node in the file that has a `scope`/`notScopes`/`assignment`/`parameters`/`enforcementMode` property.