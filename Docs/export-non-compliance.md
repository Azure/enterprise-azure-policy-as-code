# Exporting non-compliance reports

The script `Export-AzPolicyNonCompliance` exports non-compliance reports for EPAC environments in the `global-settings.jsonc` file. It outputs the reports in the `$outputFolders/non-compliance-reports` folder in two files:

- `summary.csv` contains the summary of the non-compliant resources including the non-compliant resource count
- `details.csv` contains the details of the non-compliant resources including the non-compliant resource ids

## Script parameters

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. |
| `OutputFolder` | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`. |
| `WindowsNewLineCells` | Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell |
| `Interactive` | Set to false if used non-interactive |
| `OnlyCheckManagedAssignments` | Include non-compliance data only for Policy assignments owned by this Policy as Code repo |
| `PolicySetDefinitionFilter` | Filter by Policy Set definition names (array) or ids (array). Can only be used when PolicyAssignmentFilter is not used. |
| `PolicyAssignmentFilter` | Filter by Policy Assignment names (array) or ids (array). Can only be used when PolicySetDefinitionFilter is not used. |

## Examples

```powershell
Export-NonComplianceReports -PacEnvironmentSelector "dev"
```

```powershell
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs"
```

```powershell
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -WindowsNewLineCells
```

```powershell
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -OnlyCheckManagedAssignments
```

```powershell
Export-NonComplianceReports -PolicySetDefinitionFilter "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111"
```

```powershell
Export-NonComplianceReports -PolicyAssignmentFilter "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb"
```

## Example output

### `summary.csv`

|Category|Policy|Policy Id|Non-Compliant|Unknown|Exempt|Conflicting|Not-Started|Error|
|-|-|-|-|-|-|-|-|-|
API Management|API Management APIs should use only encrypted protocols|/providers/microsoft.authorization/policydefinitions/ee7495e7-3ba7-40b6-bfee-c29e22cc75d4|1|0|0|0|0|0
API Management|API Management services should use a virtual network|/providers/microsoft.authorization/policydefinitions/ef619a2c-cc4d-4d03-b2ba-8c94a834d85b|1|0|0|0|0|0
App Configuration|App Configuration should use private link|/providers/microsoft.authorization/policydefinitions/ca610c1d-041c-4332-9d88-7ed3094967c7|1|0|0|0|0|0
App Service|App Service apps should have resource logs enabled|/providers/microsoft.authorization/policydefinitions/91a78b24-f231-4a8a-8da9-02c35b2b6510|1|0|0|0|0|0
App Service|App Service apps should only be accessible over HTTPS|/providers/microsoft.authorization/policydefinitions/a4af4a39-4135-47fb-b175-47fbdf85311d|4|0|0|0|0|0

### `details.csv`

|Category|Policy|Effect|State|Resource Id|Policy Id|Group Names|Assignments|
|-|-|-|-|-|-|-|-|
|API Management|API Management APIs should use only encrypted protocols|audit|NonCompliant|/subscriptions/96073bf6-fb80-40d4-b72f-785ec0a29c61/resourcegroups/ott-pdue2-intcall-rg001/providers/microsoft.apimanagement/service/ott-pdue2-intcall-apim001/apis/streammarkersupdate|/providers/microsoft.authorization/policydefinitions/ee7495e7-3ba7-40b6-bfee-c29e22cc75d4|azure_security_benchmark_v3.0_dp-3|/providers/microsoft.management/managementgroups/ott-prod-env/providers/microsoft.authorization/policyassignments/prod-asb|
|API Management|API Management calls to API backends should be authenticated|audit|NonCompliant|/subscriptions/96073bf6-fb80-40d4-b72f-785ec0a29c61/resourcegroups/ott-pdue2-intcall-rg001/providers/microsoft.apimanagement/service/ott-pdue2-intcall-apim001/backends/ott-pdue2-vcarch-func001|/providers/microsoft.authorization/policydefinitions/c15dcc82-b93c-4dcb-9332-fbf121685b54|azure_security_benchmark_v3.0_im-4|/providers/microsoft.management/managementgroups/ott-prod-env/providers/microsoft.authorization/policyassignments/prod-asb|
