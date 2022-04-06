# Operational Scripts

## Warning

Many scripts use a configuration value called `RootScope`. It denotes the location of the custom Policy or Initiative definitions. If this parameter/setting does not follow this rule, the scripts will break.

## Table of Contents

- [Common Script Parameters](#common-script-parameters)
- [New-AzPolicyReaderRole.ps1](#new-azpolicyreaderroleps1)
- [CreateAzRemediationTasks.ps1](#createazremediationtasksps1)
- [Get-AzEffectsForEnvironments.ps1](#get-azeffectsforenvironmentsps1)
- [Get-AzEffectsForInitiatives.ps1](#get-azeffectsforinitiativesps1)
- [Get-AzMissingTags.ps1](#get-azmissingtagsps1)
- [Get-AzResourceTags.ps1](#get-azresourcetagsps1)
- [Get-AzStorageNetworkConfig.ps1](#get-azstoragenetworkconfigps1)
- [Get-AzUserRoleAssignments.ps1](#get-azuserroleassignmentsps1)
- [Reading List](#reading-list)

<br/>

## Common Script Parameters

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Selects the tenant, rootScope, defaultSubscription, assignment scopes/notScope and file names. If omitted, interactively prompts for the value. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_ROOT_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.

<br/>[Back to top](#scripts)<br/>

## New-AzPolicyReaderRole.ps1

Creates a custom role `Policy Contributor` at the scope selected with `PacEnvironmentSelector`:

- `Microsoft.Authorization/policyAssignments/read`
- `Microsoft.Authorization/policyDefinitions/read`
- `Microsoft.Authorization/policySetDefinitions/read`

<br/>[Back to top](#scripts)<br/>

## CreateAzRemediationTasks.ps1

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The script will recurse the Management Group structure and subscriptions from the defined starting point.

- Find all Policy assignments with potential remediations
- Query Policy Insights for non-complaint resources
- Start remediation task for each Policy with non-compliant resources

<br/>[Back to top](#scripts)<br/>

## Get-AzEffectsForEnvironments.ps1

Creates a list with the effective Policy effects for the security baseline assignments per environment (DEV, DEVINT, NONPROD, PROD, etc.). The script needs the representative assignments defined for each environment in [`./Definitions/global-settings.jsonc`](#Get-RepresentativeAssignmnets_ps1).

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `outputPath` | Optional | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/AzEffects/Environments` or `./Outputs/AzEffects/Environments`.
| `outputType` | Optional | Specifies the output format <br/> `csv` is the default and creates an Excel CSV file. <br/> `json` creates the same output as a JSON file. <br/> `pipeline` pipes the output into the PowerShell pipeline. |

<br/>[Back to top](#scripts)<br/>

## Get-AzEffectsForInitiatives.ps1

Script calculates the effect parameters for the specified Initiative(s) outputing:

- Comparison table (csv) to see the differences between 2 or more initaitives (most useful for compliance Initiatives)
- List (csv) of default effects for a single initiative
- Json snippet with parameters for each initiative

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `initiativeSetSelector` | Optional | Specifies the initiative set to compare from GlobalSettings. If omitted, interactively prompts for the value. |
| `outputPath` | Optional | Plan filename. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/AzEffects/Initiatives` or `./Outputs/AzEffects/Initiatives`. |

<br/>[Back to top](#scripts)<br/>

## Get-AzMissingTags.ps1

Lists missing tags based on non-compliant Resource Groups.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv` or `./Outputs/Tags/missing-tags-results.csv`. |

<br/>[Back to top](#scripts)<br/>

## Get-AzResourceTags.ps1

Lists all resource tags in tenant.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/all-tags.csv` or `./Outputs/Tags/all-tags.csv`. |

<br/>[Back to top](#scripts)<br/>

## Get-AzStorageNetworkConfig.ps1

Lists Storage Account network configurations.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Storage/StorageNetwork.csv` or `./Outputs/Storage/StorageNetwork.csv` |

<br/>[Back to top](#scripts)<br/>

## Get-AzUserRoleAssignments.ps1

Lists Role assignments per user.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Users/RoleAssignments.csv` or `./Outputs/Users/RoleAssignments.csv` |

<br/>[Back to top](#scripts)<br/>

## Reading List

1. **[Pipeline](../Pipeline/README.md)**

1. **[Update Global Settings](../Definitions/README.md)**

1. **[Create Policy Definitions](../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../Definitions/Assignments/README.md)**

1. **[Operational Scripts](#Scripts)**

**[Return to the main page](../README.md)**
<br/>[Back to top](#scripts)<br/>
