# Operational Scripts

## Warning

Many scripts use a configuration value called `RootScope`. It denotes the location of the custom Policy or Initiative definitions. If this parameter/setting does not follow this rule, the scripts will break.

## Table of Contents

- [New-AzPolicyReaderRole.ps1](#new-azpolicyreaderroleps1)
- [Create-AzRemediationTasks.ps1](#create-azremediationtasksps1)
- [Build-PolicyAssignmentDocumentation.ps1](#build-policyassignmentdocumentationps1)
- [Get-AzMissingTags.ps1](#get-azmissingtagsps1)
- [Get-AzResourceTags.ps1](#get-azresourcetagsps1)
- [Get-AzStorageNetworkConfig.ps1](#get-azstoragenetworkconfigps1)
- [Get-AzUserRoleAssignments.ps1](#get-azuserroleassignmentsps1)
- [Reading List](#reading-list)

<br/>

## New-AzPolicyReaderRole.ps1

Creates a custom role `Policy Contributor` at the scope selected with `PacEnvironmentSelector`:

- `Microsoft.Authorization/policyAssignments/read`
- `Microsoft.Authorization/policyDefinitions/read`
- `Microsoft.Authorization/policySetDefinitions/read`

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

<br/>

## Create-AzRemediationTasks.ps1

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The script will recurse the Management Group structure and subscriptions from the defined starting point.

- Find all Policy assignments with potential remediations
- Query Policy Insights for non-complaint resources
- Start remediation task for each Policy with non-compliant resources

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

<br/>

## Build-PolicyAssignmentDocumentation.ps1

Generates documentation for assignments and initiatives based on JSON files in `$definitionsFolder/Documentation`. [See Define Documentation for details](../../Definitions/Documentation/README.md).

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `definitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `outputFolder` | Optional | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.
| `interactive` | Optional | Script is being run interactively and can request az login. It will also prompt for each file to process or skip. Defaults to $true. |
| `suppressConfirmation` | Optional |Switch parameter to suppresses prompt for confirmation of each file in interactive mode. |

<br/>

## Get-AzMissingTags.ps1

Lists missing tags based on non-compliant Resource Groups.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv` or `./Outputs/Tags/missing-tags-results.csv`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

<br/>

## Get-AzResourceTags.ps1

Lists all resource tags in tenant.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/all-tags.csv` or `./Outputs/Tags/all-tags.csv`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

<br/>

## Get-AzStorageNetworkConfig.ps1

Lists Storage Account network configurations.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Storage/StorageNetwork.csv` or `./Outputs/Storage/StorageNetwork.csv` |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

<br/>

## Get-AzUserRoleAssignments.ps1

Lists Role assignments per user.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Users/RoleAssignments.csv` or `./Outputs/Users/RoleAssignments.csv` |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

<br/>

## Get-AzPolicyAliasOutputCSV.ps1

Pull all policy aliases into a CSV file. This is helpful for Azure Policy development.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `NamespaceMatch` | Optional | Use this to cut out unnecessary aliases by specifying your desired namespace. More documentation here: https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0|
| `ResourceTypeMatch` | Optional | Resource type match can also be used to filter out unnecessary aliases. More documentation here: https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0


<br/>

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Define Policy Exemptions](../../Definitions/Exemptions/README.md)**

1. **[Documenting Assignments and Initiatives](../../Definitions/Documentation/README.md)**

1. **[Operational Scripts](#Scripts)**

**[Return to the main page](../../README.md)**
<br/>
