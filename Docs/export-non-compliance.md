# Exporting Non-Compliance Reports

The script `Export-NonComplianceReports` exports non-compliance reports for EPAC environments in the `global-settings.jsonc` file. It outputs the reports in the `$outputFolders/non-compliance-reports` folder:

- `summary-by-policy.csv` contains the summary of the non-compliant resources by Policy definition. The columns contain the resource counts.
- `summary-by-resource.csv` contains the summary of the non-compliant resources. The columns contain the number of Policies causing the non-compliance.
- `details-by-policy.csv` contains the details of the non-compliant resources by Policy definition including the non-compliant resource ids. Assignments are combined by Policy definition.
- `details-by-resource.csv` contains the details of the non-compliant resources sorted by Resource id. Assignments are combined by Resource id.
- `full-details-by-assignment.csv` contains the details of the non-compliant resources sorted by Policy Assignment id.
- `full-details-by-resource.csv` contains the details of the non-compliant resources sorted by Resource id including the Policy Assignment details.

## Script parameters

| Parameter | Explanation |
| --- | --- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. |
| `OutputFolder` | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`. |
| `WindowsNewLineCells` | Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only for Excel in Windows. Default uses commas to separate array elements within a cell |
| `Interactive` | Set to false if used non-interactive |
| `OnlyCheckManagedAssignments` | Include non-compliance data only for Policy assignments owned by this Policy as Code repo |
| `PolicyDefinitionFilter` | Filter by Policy definition names (array) or ids (array). |
| `PolicySetDefinitionFilter` | Filter by Policy Set definition names (array) or ids (array). Can only be used when PolicyAssignmentFilter is not used. |
| `PolicyAssignmentFilter` | Filter by Policy Assignment names (array) or ids (array). Can only be used when PolicySetDefinitionFilter is not used. |
| `PolicyEffectFilter` | Filter by Policy effect (array). |
| `RemediationOnly` | Filter by Policy Effect "deployifnotexists" and "modify" and compliance status "NonCompliant"

## Examples

```ps1
Export-NonComplianceReports -PacEnvironmentSelector "dev"
```

```ps1
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs"
```

```ps1
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -WindowsNewLineCells
```

```ps1
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -OnlyCheckManagedAssignments
```

```ps1
Export-NonComplianceReports -PolicySetDefinitionFilter "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111"
```

```ps1
Export-NonComplianceReports -PolicyAssignmentFilter "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb"
```

## Sample Output

### `summary-by-policy.csv`

| Category | Policy Name | Policy Id | Non Compliant | Unknown | Not Started | Exempt | Conflicting | Error | Assignment Ids | Group Names |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| General | Audit usage of custom RBAC roles | /providers/microsoft.authorization/policydefinitions/a451c1ef-c6ca-483d-87ed-f49761e3ffb5 | 9 | 0 | 0 | 0 | 0 | 0 | /providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-nist-800-53-r5,/providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-asb | azure_security_benchmark_v3.0_pa-7,nist_sp_800-53_r5_ac-6(7),nist_sp_800-53_r5_ac-2(7),nist_sp_800-53_r5_ac-6,nist_sp_800-53_r5_ac-2 |
| Regulatory Compliance | Control use of portable storage devices | /providers/microsoft.authorization/policydefinitions/0a8a1a7d-16d3-4d8e-9f2c-6b8d9e1c7c1d | 0 | 0 | 0 | 0 | 0 | 0 | /providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-nist-800-53-r5,/providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-asb | azure_security_benchmark_v3.0_pa-7,nist_sp_800-53_r5_ac-6(7),nist_sp_800-53_r5_ac-2(7),nist_sp_800-53_r5_ac-6,nist_sp_800-53_r5_ac-2 |
| Regulatory Compliance | Deploy Azure Policy to audit Windows VMs that do not use managed disks | /providers/microsoft.authorization/policydefinitions/0b2b84f2-eb8a-4f0a-8a1c-0c0d6e4cdeea | 0 | 0 | 0 | 0 | 0 | 0 | /providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-nist-800-53-r5,/providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-asb | azure_security_benchmark_v3.0_pa-7,nist_sp_800-53_r5_ac-6(7),nist_sp_800-53_r5_ac-2(7),nist_sp_800-53_r5_ac-6,nist_sp_800-53_r5_ac-2 |
| Regulatory Compliance | Deploy Azure Policy to audit Windows VMs that do not use managed disks | /providers/microsoft.authorization/policydefinitions/0b2b84f2-eb8a-4f0a-8a1c-0c0d6e4cdeea | 0 | 0 | 0 | 0 | 0 | 0 | /providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-nist-800-53-r5,/providers/microsoft.management/managementgroups/pac-heinrich-dev-dev/providers/microsoft.authorization/policyassignments/dev-asb | azure_security_benchmark_v3.0_pa-7,nist_sp_800-53_r5_ac-6(7),nist_sp_800-53_r5_ac-2(7),nist_sp_800-53_r5_ac-6,nist_sp_800-53_r5_ac-2 |

### `summary-by-resource.csv`

| Resource Id | Subscription Id | Subscription Name | Resource Group | Resource Type | Resource Name | Resource Qualifier | Non Compliant | Unknown | Not Started | Exempt | Conflicting | Error |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| /subscriptions/******************************** | ******************************** | PAC-DEV-001 |  | subscriptions |  |  | 25 | 481 | 0 | 0 | 0 | 0 |
| /subscriptions/********************************/providers/microsoft.authorization/roledefinitions/0b00bc79-2207-410c-b9d5-d5d182ad514f | ******************************** | PAC-DEV-001 |  | microsoft.authorization/roledefinitions | 0b00bc79-2207-410c-b9d5-d5d182ad514f |  | 0 | 0 | 0 | 0 | 0 | 0 |
| /subscriptions/********************************/providers/microsoft.authorization/roledefinitions/0b00bc79-2207-410c-b9d5-d5d182ad514f | ******************************** | PAC-DEV-001 |  | microsoft.authorization/roledefinitions | 0b00bc79-2207-410c-b9d5-d5d182ad514f |  | 0 | 0 | 0 | 0 | 0 | 0 |
| /subscriptions/********************************/providers/microsoft.authorization/roledefinitions/0b00bc79-2207-410c-b9d5-d5d182ad514f | ******************************** | PAC-DEV-001 |  | microsoft.authorization/roledefinitions | 0b00bc79-2207-410c-b9d5-d5d182ad514f |  | 0 | 0 | 0 | 0 | 0 | 0 |
