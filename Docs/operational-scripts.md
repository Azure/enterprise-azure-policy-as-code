# Operational Scripts

## New-AzPolicyReaderRole.ps1

Creates a custom role `Policy Reader` at the scope selected with `PacEnvironmentSelector`:

* `Microsoft.Management/register/action`
* `Microsoft.Authorization/policyassignments/read`
* `Microsoft.Authorization/policydefinitions/read`
* `Microsoft.Authorization/policyexemptions/read`
* `Microsoft.Authorization/policysetdefinitions/read`
* `Microsoft.PolicyInsights/*`
* `Microsoft.Support/*`

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`. |
| `interactive` | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Create-AzRemediationTasks.ps1

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The script will recurse the Management Group structure and subscriptions from the defined starting point.

* Find all Policy assignments with potential remediations
* Query Policy Insights for non-complaint resources
* Start remediation task for each Policy with non-compliant resources

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`. |
| `interactive` | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Build-DefinitionsFolder.ps1

This script has been replaced by `Export-AzPolicyResources.ps1`. See [Extract existing Policy Resources from an Environment](extract-existing-policy-resources.md).

## Build-PolicyAssignmentDocumentation.ps1

Generates documentation for Assignments and Policy Sets based on JSON files in `$definitionsFolder/Documentation`. [See Define Documentation for details](documenting-assignments-and-policy-sets.md).

|Parameter | Explanation |
|----------|-------------|
| `definitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `outputFolder` | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.
| `interactive` | Script is being run interactively and can request az login. It will also prompt for each file to process or skip. Defaults to $true. |
| `suppressConfirmation` | Switch parameter to suppresses prompt for confirmation of each file in interactive mode. |

## Get-AzMissingTags.ps1

Lists missing tags based on non-compliant Resource Groups.

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv` or `./Outputs/Tags/missing-tags-results.csv`. |
| `interactive` | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzResourceTags.ps1

Lists all resource tags in tenant.

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/all-tags.csv` or `./Outputs/Tags/all-tags.csv`. |
| `interactive` | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzStorageNetworkConfig.ps1

Lists Storage Account network configurations.

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Storage/StorageNetwork.csv` or `./Outputs/Storage/StorageNetwork.csv` |
| `interactive` | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzUserRoleAssignments.ps1

Lists Role assignments per user.

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Users/RoleAssignments.csv` or `./Outputs/Users/RoleAssignments.csv` |
| `interactive` | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzPolicyAliasOutputCSV.ps1

Pull all policy aliases into a CSV file. This is helpful for Azure Policy development.

|Parameter | Explanation |
|----------|-------------|
| `NamespaceMatch` | Use this to cut out unnecessary aliases by specifying your desired namespace. More documentation here: <https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0> |
| `ResourceTypeMatch` | Resource type match can also be used to filter out unnecessary aliases. More documentation here: <https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0> |

## New-EPACPolicyDefinition.ps1

Exports a policy definition from Azure to a local file in the EPAC format. Works for both Policies and set definitionsPolicy Sets

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PolicyDefinitionId`| Required | Resource ID in Azure for the policy you want to export - can take input from a pipeline |
| `OutputFolder` | Optional | Output folder for the exported policy definition - default is JSON output to console |

## New-EPACPolicyAssignmentDefinition.ps1

Exports a policy assignment from Azure to a local file in the EPAC format. Provides a base template only - you may have to manipulate the file to fit in to your current assignment structure

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PolicyAssignmentId`| Required | Resource ID in Azure for the policy assignment you want to export|
| `OutputFolder` | Optional | Output folder for the exported policy assignment - - default is JSON output to console |

## New-EPACDefinitionFolder.ps1

Creates a definitions folder with the correct folder structure and blank global settings file.

|Parameter | Explanation |
|----------|-------------|
| `DefinitionsRootFolder`| Folder name for definitions (default is `Definitions`)|
