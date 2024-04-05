# Operational Scripts

The scripts are detailed in the [reference page](operational-scripts-reference.md) including  syntax, descriptions and parameters.

## Batch Creation of Remediation Tasks

The script `Create-AzRemediationTasks` creates remediation tasks for all non-compliant resources for EPAC environments in the `global-settings.jsonc` file.

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The script will recurse the Management Group structure and subscriptions from the defined starting point.

* Find all Policy assignments with potential remediation capable resources
* Query Policy Insights for non-complaint resources
* Start remediation task for each Policy with non-compliant resources
* Switch parameter `-OnlyCheckManagedAssignments` includes non-compliance data only for Policy assignments owned by this Policy as Code repo.

#### Links

- [Remediate non-compliant resources with Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal)
- [Start-AzPolicyRemediation](https://learn.microsoft.com/en-us/powershell/module/az.policyinsights/start-azpolicyremediation?view=azps-10.1.0)

## Policy Resources Exports

- `Export-AzPolicyResources` exports Azure Policy resources in EPAC. It also generates documentation for the exported resources (can be suppressed with `-SuppressDocumentation`). See usage documentation in [Extract existing Policy Resources](epac-extracting-policy-resources.md).
- `Get-AzExemptions` retrieves Policy Exemptions from an EPAC environment and saves them to files.
- `Get-AzPolicyAliasOutputCSV` exports Policy Aliases to CSV format.

## Hydration Kit

The Hydration Kit is a set of scripts that can be used to deploy an EPAC environment from scratch. The scripts are documented in the [Hydration Kit](operational-scripts-hydration-kit.md) page.

## CI/CD Helpers

The scripts `Create-AzureDevOpsBug` and `Create-GitHubIssue` create a Bug or Issue when there are one or multiple failed Remediation Tasks.

## Documenting Policy

`Build-PolicyDocumentation` builds documentation from instructions in the `policyDocumentations` folder reading the deployed Policy Resources from the EPAC environment. It is also used to generate parameter/effect CSV files for Policy Assignment files. 

See usage documentation in [Documenting Policy](operational-scripts-documenting-policy.md).

## Non-compliance Reports

`Export-NonComplianceReports` exports non-compliance reports for EPAC environments . It outputs the reports in the `$OutputFolders/non-compliance-reports` folder.

- `summary-by-policy.csv` contains the summary of the non-compliant resources by Policy definition. The columns contain the resource counts.
- `summary-by-resource.csv` contains the summary of the non-compliant resources. The columns contain the number of Policies causing the non-compliance.
- `details-by-policy.csv` contains the details of the non-compliant resources by Policy definition including the non-compliant resource ids. Assignments are combined by Policy definition.
- `details-by-resource.csv` contains the details of the non-compliant resources sorted by Resource id. Assignments are combined by Resource id.
- `full-details-by-assignment.csv` contains the details of the non-compliant resources sorted by Policy Assignment id.
- `full-details-by-resource.csv` contains the details of the non-compliant resources sorted by Resource id including the Policy Assignment details.

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

