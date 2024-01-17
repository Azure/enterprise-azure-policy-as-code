# Operational Scripts

## Build-DefinitionsFolder.ps1

This script has been replaced by `Export-AzPolicyResources.ps1`. See [Extract existing Policy Resources from an Environment](extract-existing-policy-resources.md).

## Build-PolicyDocumentation.ps1

Builds documentation from instructions in policyDocumentations folder reading the deployed Policy Resources from the EPAC environment.

| Parameter               | Explanation                                                                                                                                                                       |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DefinitionsRootFolder` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.                                  |
| `OutputFileName`        | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv` or `./Outputs/Tags/missing-tags-results.csv`.                           |
| `Interactive`           | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise.                                  |

## Create-AzRemediationTasks.ps1

This PowerShell script creates remediation tasks for all non-compliant resources in the current Azure Active Directory (AAD) tenant. If one or multiple remediation tasks fail, their respective objects are added to a PowerShell variable that is outputted for later use in the Azure DevOps Pipeline.

| Parameter                     | Explanation                                                                                                                                                                       |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector`      | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`       | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`.                                                                       |
| `Interactive`                 | Set to false if used non-interactive.                                                                                                                                             |
| `OnlyCheckManagedAssignments` | Include non-compliance data only for Policy assignments owned by this Policy as Code repo.                                                                                        |
| `PolicyDefinitionFilter`      | Filter by Policy definition names (array) or ids (array).                                                                                                                         |
| `PolicySetDefinitionFilter`   | Filter by Policy Set definition names (array) or ids (array).                                                                                                                     |
| `PolicyAssignmentFilter`      | Filter by Policy Assignment names (array) or ids (array).                                                                                                                         |
| `PolicyEffectFilter`          | Filter by Policy effect (array).                                                                                                                                                  |

### Examples

1. `Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev"`

2. `Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions"`

3. `Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -Interactive $false`

4. `Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -OnlyCheckManagedAssignments`

5. `Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -PolicyDefinitionFilter "Require tag 'Owner' on resource groups" -PolicySetDefinitionFilter "Require tag 'Owner' on resource groups" -PolicyAssignmentFilter "Require tag 'Owner' on resource groups"`

### Inputs

None.

### Outputs

The Create-AzRemediationTasks.ps1 PowerShell script outputs multiple string values for logging purposes, a JSON string containing all the failed Remediation Tasks and a boolean value, both of which are used in a later stage of the Azure DevOps Pipeline.

## Create-AzureDevOpsBug.ps1

This PowerShell script creates a Bug when there are one or multiple failed Remediation Tasks.

The Create-AzureDevOpsBug.ps1 PowerShell script creates a Bug on the current Iteration of a team when one or multiple Remediation Tasks failed. The Bug is formatted as an HTML table and contains information on the name and Url properties. As a result, the team can easily locate and resolve the Remediation Tasks that failed.

| Parameter                                | Explanation                                                                                                                                        |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FailedPolicyRemediationTasksJsonString` | Specifies the JSON string that contains the objects of one or multiple failed Remediation Tasks.                                                   |
| `ModuleName`                             | Specifies the name of the PowerShell module installed at the beginning of the PowerShell script. By default, this is the VSTeam PowerShell Module. |
| `OrganizationName`                       | Specifies the name of the Azure DevOps Organization.                                                                                               |
| `ProjectName`                            | Specifies the name of the Azure DevOps Project.                                                                                                    |
| `PersonalAccessToken`                    | Specifies the Personal Access Token that is used for authentication purposes. Make sure that you use the AzureKeyVault@2 task for this purpose.    |
| `TeamName`                               | Specifies the name of the Azure DevOps team.                                                                                                       |

### Example

`Create-AzureDevOpsBug.ps1 
  -FailedPolicyRemediationTasksJsonString '<JSON string>'
-ModuleName 'VSTeam'  -OrganizationName 'bavanben'
-ProjectName 'Contoso'  -PersonalAccessToken '<secret string>'
-TeamName 'Contoso Team'`

## Create-GitHubIssue.ps1

This PowerShell script creates an Issue when there are one or multiple failed Remediation Tasks.

The Create-GitHubIssue.ps1 PowerShell script creates an Issue in a GitHub Repository that is located under a GitHub Organization when one or multiple Remediation Tasks failed. The Bug is formatted as an HTML table and contains information on the name and Url properties. As a result, the team can easily locate and resolve the Remediation Tasks that failed.

| Parameter                                | Explanation                                                                                      |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `FailedPolicyRemediationTasksJsonString` | Specifies the JSON string that contains the objects of one or multiple failed Remediation Tasks. |
| `OrganizationName`                       | Specifies the name of the GitHub Organization.                                                   |
| `RepositoryName`                         | Specifies the name of the GitHub Repository.                                                     |
| `PersonalAccessToken`                    | Specifies the Personal Access Token that is used for authentication purposes.                    |

### Example

`Create-GitHubIssue.ps1
  -FailedPolicyRemediationTasksJsonString '<JSON string>'
-OrganizationName 'basvanbennekommsft'  -RepositoryName 'Blog-Posts'
-PersonalAccessToken '<secret string>'`

## Export-AzPolicyResources.ps1

Exports Azure Policy resources in EPAC format or raw format. It has 4 operating modes - see -Mode parameter for details. It also generates documentation for the exported resources (can be suppressed with -SuppressDocumentation). To just generate EPAC formatted Definitions without generating documentation files, use -supressEpacOutput.

| Parameter               | Explanation                                                                                                                                                                                                     |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`.                                                                                                     |
| `OutputFolder`          | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.                                                                                                                        |
| `Interactive`           | Set to false if used non-interactive. Defaults to `$true`.                                                                                                                                                      |
| `IncludeChildScopes`    | Switch parameter to include Policies and Policy Sets definitions in child scopes                                                                                                                                |
| `IncludeAutoAssigned`   | Switch parameter to include Assignments auto-assigned by Defender for Cloud                                                                                                                                     |
| `ExemptionFiles`        | Create Exemption files (none=suppress, csv=as a csv file, json=as a json or jsonc file). Defaults to 'csv'.                                                                                                     |
| `FileExtension`         | File extension type for the output files. Defaults to '.jsonc'.                                                                                                                                                 |
| `Mode`                  | Operating mode: 'export', 'collectRawFile', 'exportFromRawFiles', 'exportRawToPipeline', 'psrule'                                                                                                               |
| `InputPacSelector`      | Limits the collection to one EPAC environment, useful for non-interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'. The default is '\*' which will execute all EPAC-Environments. |
| `SuppressDocumentation` | Suppress documentation generation.                                                                                                                                                                              |
| `SuppressEpacOutput`    | Suppress output generation in EPAC format.                                                                                                                                                                      |
| `PSRuleIgnoreFullScope` | Ignore full scope for PsRule Extraction                                                                                                                                                                         |

### Example

`Export-AzPolicyResources -DefinitionsRootFolder ./Definitions -OutputFolder ./Outputs -Interactive $true -IncludeChildScopes -IncludeAutoAssigned -ExemptionFiles csv -FileExtension jsonc -Mode export -InputPacSelector '\*'`

## Export-NonComplianceReports.ps1

Exports Non-Compliance Reports in CSV format.

| Parameter                     | Explanation                                                                                                                                                                       |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector`      | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`       | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`.                                                                       |
| `OutputFolder`                | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.                                                                                          |
| `WindowsNewLineCells`         | Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only for Excel in Windows. Default uses commas to separate array elements within a cell.   |
| `Interactive`                 | Set to false if used non-interactive.                                                                                                                                             |
| `OnlyCheckManagedAssignments` | Include non-compliance data only for Policy assignments owned by this Policy as Code repo.                                                                                        |
| `PolicyDefinitionFilter`      | Filter by Policy definition names (array) or ids (array).                                                                                                                         |
| `PolicySetDefinitionFilter`   | Filter by Policy Set definition names (array) or ids (array).                                                                                                                     |
| `PolicyAssignmentFilter`      | Filter by Policy Assignment names (array) or ids (array).                                                                                                                         |
| `PolicyEffectFilter`          | Filter by Policy Effect (array).                                                                                                                                                  |
| `ExcludeManualPolicyEffect`   | Switch parameter to filter out Policy Effect Manual.                                                                                                                              |
| `RemediationOnly`             | Filter by Policy Effect "deployifnotexists" and "modify" and compliance status "NonCompliant".                                                                                    |

### Examples

1. `Export-NonComplianceReports -PacEnvironmentSelector "dev"`

2. `Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs"`

3. `Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -WindowsNewLineCells`

4. `Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -OnlyCheckManagedAssignments`

5. `Export-NonComplianceReports -PolicySetDefinitionFilter "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111"`

6. `Export-NonComplianceReports -PolicyAssignmentFilter "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb"`

7. `Export-NonComplianceReports -PolicyEffectFilter "deny"`

8. `Export-NonComplianceReports -PolicyEffectFilter "deny", "audit"`

9. `Export-NonComplianceReports -ExcludeManualPolicyEffect`

## Format-PolicyName.ps1

Formats a given display name into a scrubbed string that can be used as a policy name.

| Parameter     | Explanation                       |
| ------------- | --------------------------------- |
| `DisplayName` | The display name to be formatted. |

### Example

`Format-PolicyName.ps1 -DisplayName "My Policy Name"`

## Get-AzExemptions.ps1

Retrieves Policy Exemptions from an EPAC environment and saves them to files.

| Parameter                | Explanation                                                                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`  | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`.                                                                       |
| `OutputFolder`           | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.                                                                                          |
| `Interactive`            | Set to false if used non-interactive.                                                                                                                                             |
| `FileExtension`          | File extension type for the output files. Valid values are json and jsonc. Defaults to json.                                                                                      |
| `ActiveExemptionsOnly`   | Set to true to only generate files for active (not expired and not orphaned) exemptions. Defaults to false.                                                                       |

### Examples

`Get-AzExemptions.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFolder "C:\Src\Outputs" -Interactive $true -FileExtension "jsonc"`

`Get-AzExemptions.ps1 -Interactive $true`

## Get-AzMissingTags.ps1

Lists missing tags based on non-compliant Resource Groups.

| Parameter                | Explanation                                                                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`  | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.                                  |
| `OutputFileName`         | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv` or `./Outputs/Tags/missing-tags-results.csv`.                           |
| `Interactive`            | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise.                                  |

### Example

`Get-AzMissingTags.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFileName "missing-tags-results.csv" -Interactive $true`

## Get-AzPolicyAliasOutputCSV.ps1

Pull all policy aliases into a CSV file. This is helpful for Azure Policy development.

| Parameter           | Explanation                                                                                                                                                                                                 |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NamespaceMatch`    | Use this to cut out unnecessary aliases by specifying your desired namespace. More documentation here: <https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0> |
| `ResourceTypeMatch` | Resource type match can also be used to filter out unnecessary aliases. More documentation here: <https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0>       |

### Example

`Get-AzPolicyAliasOutputCSV.ps1 -OutputFileName "PolicyAliases.csv"`

## Get-AzResourceTags.ps1

Lists all resource tags in tenant.

| Parameter                | Explanation                                                                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`  | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.                                  |
| `OutputFileName`         | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/all-tags.csv` or `./Outputs/Tags/all-tags.csv`.                                                   |
| `Interactive`            | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise.                                  |

### Example

`Get-AzResourceTags.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFileName "resource-tags-results.csv" -Interactive $true`

## Get-AzStorageNetworkConfig.ps1

Lists Storage Account network configurations.

| Parameter                | Explanation                                                                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`  | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.                                  |
| `OutputFileName`         | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Storage/StorageNetwork.csv` or `./Outputs/Storage/StorageNetwork.csv`                                  |
| `Interactive`            | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise.                                  |

### Example

`Get-AzStorageNetworkConfig.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFileName "StorageNetwork.csv" -Interactive $true`

## Get-AzUserRoleAssignments.ps1

Lists Role assignments per user.

| Parameter                | Explanation                                                                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`  | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.                                  |
| `OutputFileName`         | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Users/RoleAssignments.csv` or `./Outputs/Users/RoleAssignments.csv`                                    |
| `Interactive`            | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise.                                  |

### Example

`Get-AzUserRoleAssignments.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFileName "RoleAssignments.csv" -Interactive $true`

## New-AzPolicyReaderRole.ps1

Creates a custom role 'Policy Reader' that provides read access to all Policy resources for the purpose of planning the EPAC deployments.

| Parameter                | Explanation                                                                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder`  | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`.                                                                       |
| `Interactive`            | Set to false if used non-interactive.                                                                                                                                             |

### Examples

`New-AzPolicyReaderRole.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -Interactive $true`

`New-AzPolicyReaderRole.ps1 -Interactive $true`

## New-EPACDefinitionFolder.ps1

Creates a new EPAC definition folder.

| Parameter               | Explanation                                                      |
| ----------------------- | ---------------------------------------------------------------- |
| `DefinitionFolderName`  | The name of the new definition folder.                           |
| `DefinitionsRootFolder` | The root folder where the new definition folder will be created. |

### Example

`New-EPACDefinitionFolder.ps1 -DefinitionFolderName "MyNewDefinition" -DefinitionsRootFolder "C:\Src\Definitions"`

## New-EPACGlobalSettings.ps1

Creates a global-settings.jsonc file with a new guid, managed identity location and tenant information.

| Parameter                 | Explanation                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------- |
| `ManagedIdentityLocation` | The Azure location to store the managed identities.                                                 |
| `TenantId`                | The Azure tenant ID for the solution.                                                               |
| `DefinitionsRootFolder`   | The folder path to where the New-EPACDefinitionsFolder command created the definitions root folder. |
| `DeploymentRootScope`     | The root management group to export definitions and assignments.                                    |

### Example

`New-EPACGlobalSettings.ps1 -ManagedIdentityLocation NorthCentralUS -TenantId 00000000-0000-0000-0000-000000000000 -DefinitionsRootFolder C:\definitions\ -DeploymentRootScope /providers/Microsoft.Management/managementGroups/mgroup1`

## New-EPACPolicyAssignmentDefinition.ps1

Exports a policy assignment from Azure to a local file in the EPAC format. Provides a base template only - you may have to manipulate the file to fit in to your current assignment structure

| Parameter            | Required | Explanation                                                                            |
| -------------------- | -------- | -------------------------------------------------------------------------------------- |
| `PolicyAssignmentId` | Required | Resource ID in Azure for the policy assignment you want to export                      |
| `OutputFolder`       | Optional | Output folder for the exported policy assignment - - default is JSON output to console |

### Example

`New-EPACPolicyAssignmentDefinition.ps1 -PolicyAssignmentId "/providers/Microsoft.Authorization/policyAssignments/assignment1" -OutputFolder "C:\Src\Definitions\Assignments"`

## New-EPACPolicyDefinition.ps1

Exports a Policy definition from Azure to a local file in the EPAC format.

| Parameter            | Explanation                                                    |
| -------------------- | -------------------------------------------------------------- |
| `PolicyDefinitionId` | The ID of the Policy definition to export.                     |
| `OutputFolder`       | The folder where the exported Policy definition will be saved. |

### Example

`New-EPACPolicyDefinition.ps1 -PolicyDefinitionId "/providers/Microsoft.Management/managementGroups/epac/providers/Microsoft.Authorization/policyDefinitions/Append-KV-SoftDelete" -OutputFolder`
