# Operational Scripts

**On this page**

* [New-AzPolicyReaderRole.ps1](#new-azpolicyreaderroleps1)
* [Create-AzRemediationTasks.ps1](#create-azremediationtasksps1)
* [Build-DefinitionsFolder.ps1](#build-definitionsfolderps1)
* [Build-PolicyAssignmentDocumentation.ps1](#build-policyassignmentdocumentationps1)
* [Get-AzMissingTags.ps1](#get-azmissingtagsps1)
* [Get-AzResourceTags.ps1](#get-azresourcetagsps1)
* [Get-AzStorageNetworkConfig.ps1](#get-azstoragenetworkconfigps1)
* [Get-AzUserRoleAssignments.ps1](#get-azuserroleassignmentsps1)
* [Get-AzPolicyAliasOutputCSV.ps1](#get-azpolicyaliasoutputcsvps1)
* [New-EPACPolicyDefinition.ps1](#new-epacpolicydefinitionps1)
* [New-EPACPolicyAssignmentDefinition.ps1](#new-epacpolicyassignmentdefinitionps1)
* [Reading List](#reading-list)

## New-AzPolicyReaderRole.ps1

Creates a custom role `Policy Reader` at the scope selected with `PacEnvironmentSelector`:

* `Microsoft.Management/register/action`
* `Microsoft.Authorization/policyassignments/read`
* `Microsoft.Authorization/policydefinitions/read`
* `Microsoft.Authorization/policyexemptions/read`
* `Microsoft.Authorization/policysetdefinitions/read`
* `Microsoft.PolicyInsights/*`
* `Microsoft.Support/*`

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Create-AzRemediationTasks.ps1

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The script will recurse the Management Group structure and subscriptions from the defined starting point.

* Find all Policy assignments with potential remediations
* Query Policy Insights for non-complaint resources
* Start remediation task for each Policy with non-compliant resources

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Build-DefinitionsFolder.ps1

[Extract existing Policies, Policy Sets, and Policy Assignments](extract-existing-policy-resources.md) and outputs them in EPAC format into folders which can be directly copied to the `Definitions` folder. This useful when initially transitioning from a pre-EPAC to EPAC environment.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `definitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `outputFolder` | Optional | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.
| `interactive` | Optional | Script is being run interactively and can request az login. It will also prompt for each file to process or skip. Defaults to $true. |
| `includeChildScopes` | Optional | Switch parameter to include Policies and Policy Sets in child scopes; child scopes are normally ignored for definitions. This does not impact Policy Assignments. |

## Build-PolicyAssignmentDocumentation.ps1

Generates documentation for Assignments and Policy Sets based on JSON files in `$definitionsFolder/Documentation`. [See Define Documentation for details](documenting-assignments-and-policy-sets.md).

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `definitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `outputFolder` | Optional | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.
| `interactive` | Optional | Script is being run interactively and can request az login. It will also prompt for each file to process or skip. Defaults to $true. |
| `suppressConfirmation` | Optional | Switch parameter to suppresses prompt for confirmation of each file in interactive mode. |

## Get-AzMissingTags.ps1

Lists missing tags based on non-compliant Resource Groups.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv` or `./Outputs/Tags/missing-tags-results.csv`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzResourceTags.ps1

Lists all resource tags in tenant.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/all-tags.csv` or `./Outputs/Tags/all-tags.csv`. |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzStorageNetworkConfig.ps1

Lists Storage Account network configurations.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Storage/StorageNetwork.csv` or `./Outputs/Storage/StorageNetwork.csv` |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzUserRoleAssignments.ps1

Lists Role assignments per user.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFileName` | Optional | Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Users/RoleAssignments.csv` or `./Outputs/Users/RoleAssignments.csv` |
| `interactive` | Optional | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Get-AzPolicyAliasOutputCSV.ps1

Pull all policy aliases into a CSV file. This is helpful for Azure Policy development.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `NamespaceMatch` | Optional | Use this to cut out unnecessary aliases by specifying your desired namespace. More documentation here: <https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0> |
| `ResourceTypeMatch` | Optional | Resource type match can also be used to filter out unnecessary aliases. More documentation here: <https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azpolicyalias?view=azps-8.3.0> |

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

## Reading List

* [Setup DevOps Environment](operating-environment.md) .
* [Create a source repository and import the source code](clone-github.md) from this repository.
* [Select the desired state strategy](desired-state-strategy.md)
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.
* Optional: generate a starting point for the `Definitions` folders:
  * [Extract existing Policy resources from an environment](extract-existing-policy-resources.md).
  * [Import Policies from the Cloud Adoption Framework](cloud-adoption-framework.md).
* [Add custom Policies](policy-definitions.md).
* [Add custom Policy Sets](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).
* Import Policies from the [Cloud Adoption Framework](cloud-adoption-framework.md).
* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](operational-scripts.md).

**[Return to the main page](../README.md)**
