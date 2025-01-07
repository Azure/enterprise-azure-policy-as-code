# Scripts References

## Script `Build-PolicyDocumentation`

Builds documentation from instructions in policyDocumentations folder reading the deployed Policy Resources from the EPAC environment.

```ps1
Build-PolicyDocumentation [[-DefinitionsRootFolder] <String>] [[-OutputFolder] <String>] [-WindowsNewLineCells] [-Interactive <Boolean>] [-SuppressConfirmation] [-IncludeManualPolicies] [<CommonParameters>]
```

### Parameters

#### `-DefinitionsRootFolder <String>`

Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

#### `-OutputFolder <String>`

Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

#### `-WindowsNewLineCells [<SwitchParameter>]`

Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only for Excel in Windows. Default uses commas to separate array elements within a cell

#### `-Interactive <Boolean>`

Set to false if used non-interactive

#### `-SuppressConfirmation [<SwitchParameter>]`

Suppresses prompt for confirmation to delete an existing file in interactive mode

#### `-IncludeManualPolicies [<SwitchParameter>]`

Include Policies with effect Manual. Default: do not include Policies with effect Manual.

## Script `New-AzRemediationTasks`

The New-AzRemediationTasks PowerShell creates remediation tasks for all non-compliant resources in the current AAD tenant. If one or multiple remediation tasks fail, their respective objects are added to a PowerShell variable that is outputted for later use in the Azure DevOps Pipeline.

```ps1
New-AzRemediationTasks [[-PacEnvironmentSelector] <String>] [-DefinitionsRootFolder <String>] [-Interactive <Boolean>] [-OnlyCheckManagedAssignments] [-PolicyDefinitionFilter <String[]>] [-PolicySetDefinitionFilter <String[]>] [-PolicyAssignmentFilter <String[]>] [-PolicyEffectFilter <String[]>] [-NoWait] [-TestRun] [-Confirm] [<CommonParameters>]
```

### Parameters

#### `-PacEnvironmentSelector <String>`

Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

#### `-DefinitionsRootFolder <String>`

Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

#### `-Interactive <Boolean>`

Set to false if used non-interactive

#### `-OnlyCheckManagedAssignments [<SwitchParameter>]`

Include non-compliance data only for Policy assignments owned by this Policy as Code repo

#### `-PolicyDefinitionFilter <String[]>`

Filter by Policy definition names (array) or ids (array).

#### `-PolicySetDefinitionFilter <String[]>`

Filter by Policy Set definition names (array) or ids (array).

#### `-PolicyAssignmentFilter <String[]>`

Filter by Policy Assignment names (array) or ids (array).

#### `-PolicyEffectFilter <String[]>`

Filter by Policy effect (array).

#### `-NoWait [<SwitchParameter>]`
Indicates that the script should not wait for the remediation tasks to complete.

#### `-TestRun [<SwitchParameter>]`
Simulates the actions of the command without actually performing them. Useful for testing.

#### `-Confirm [<SwitchParameter>]`
Prompts for confirmation before executing the command.

## Script `New-AzureDevOpsBug`

Creates a Bug on the current Iteration of a team when one or multiple Remediation Tasks fail. The Bug is formatted as an HTML table and contains information on the name and URL properties. As a result, the team can easily locate and resolve the Remediation Tasks that failed.

```ps1
New-AzureDevOpsBug [-FailedPolicyRemediationTasksJsonString] <String> [-ModuleName] <String> [-OrganizationName] <String> [-ProjectName] <String> [-PersonalAccessToken] <String> [-TeamName] <String> [<CommonParameters>]
```

### Parameters

#### `-FailedPolicyRemediationTasksJsonString <String>`

Specifies the JSON string that contains the objects of one or multiple failed Remediation Tasks.

#### `-ModuleName <String>`

Specifies the name of the PowerShell module installed at the beginning of the PowerShell script. By default, this is the VSTeam PowerShell Module.

#### `-OrganizationName <String>`

Specifies the name of the Azure DevOps Organization.

#### `-ProjectName <String>`

Specifies the name of the Azure DevOps Project.

#### `-PersonalAccessToken <String>`

Specifies the Personal Access Token that is used for authentication purposes. Make sure that you use the AzureKeyVault@2 task (link below) for this purpose.

#### `-TeamName <String>`

Specifies the name of the Azure DevOps team.

## Script `New-GitHubIssue`

Creates an Issue in a GitHub Repository that is located under a GitHub Organization when one or multiple Remediation Tasks fail. The Bug is formatted as an HTML table and contains information on the name and URL properties. As a result, the team can easily locate and resolve the Remediation Tasks that failed.

```ps1
New-GitHubIssue [-FailedPolicyRemediationTasksJsonString] <String> [-OrganizationName] <String> [-RepositoryName] <String> [-PersonalAccessToken] <String> [<CommonParameters>]
```

### Parameters

#### `-FailedPolicyRemediationTasksJsonString <String>`

Specifies the JSON string that contains the objects of one or multiple failed Remediation Tasks.

#### `-OrganizationName <String>`

Specifies the name of the GitHub Organization.

#### `-RepositoryName <String>`

Specifies the name of the GitHub Repository.

#### `-PersonalAccessToken <String>`

## Script `Export-AzPolicyResources`

Exports Azure Policy resources in EPAC format or raw format. It also generates documentation for the exported resources (can be suppressed with `-SuppressDocumentation`).

```ps1
Export-AzPolicyResources [[-DefinitionsRootFolder] <String>] [[-OutputFolder] <String>] [[-Interactive] <Boolean>] [-IncludeChildScopes] [-IncludeAutoAssigned] [[-ExemptionFiles] <String>] [[-FileExtension] <String>] [[-Mode] <String>] [[-InputPacSelector] <String>] [-SuppressDocumentation] [-SuppressEpacOutput] [-PSRuleIgnoreFullScope] [<CommonParameters>]
```

### Parameters

#### `-DefinitionsRootFolder <String>`

        Definitions folder path. Defaults to environment variable $env:PAC_DEFINITIONS_FOLDER or './Definitions'.

#### `-OutputFolder <String>`

Output Folder. Defaults to environment variable $env:PAC_OUTPUT_FOLDER or './Outputs'.

#### `-Interactive <Boolean>`

Set to false if used non-interactive. Defaults to $true.

#### `-IncludeChildScopes [<SwitchParameter>]`

Switch parameter to include Policies and Policy Sets definitions in child scopes

#### `-IncludeAutoAssigned [<SwitchParameter>]`

Switch parameter to include Assignments auto-assigned by Defender for Cloud

#### `-ExemptionFiles <String>`

Create Exemption files (none=suppress, csv=as a csv file, json=as a json or jsonc file). Defaults to 'csv'.

#### `-FileExtension <String>`

File extension type for the output files. Defaults to '.jsonc'.

#### `-Mode <String>`

Operating mode:

- `export` exports EPAC environments in EPAC format, which should be used with -Interactive $true in a multi-tenant scenario, or used with an inputPacSelector to limit the scope to one EPAC environment.
- `collectRawFile` exports the raw data only; Often used with 'inputPacSelector' when running non-interactive in a multi-tenant scenario to collect the raw data once per tenant into a file named after the EPAC environment
- `exportFromRawFiles` reads the files generated with one or more runs of b) and outputs the files the same as normal 'export'.
- `exportRawToPipeline` exports EPAC environments in EPAC format, which should be used with `-Interactive` $true in a multi-tenant scenario, or used with an inputPacSelector to limit the scope to one EPAC environment.
- `psrule` exports EPAC environment into a file which can be used to create policy rules for PSRule for Azure

#### `-InputPacSelector <String>`

Limits the collection to one EPAC environment, useful for non-interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'.
        The default is '*' which will execute all EPAC-Environments.

#### `-SuppressDocumentation [<SwitchParameter>]`

Suppress documentation generation.

#### `-SuppressEpacOutput [<SwitchParameter>]`

Suppress output generation in EPAC format.

#### `-PSRuleIgnoreFullScope [<SwitchParameter>]`

Ignore full scope for PsRule Extraction

## Script `Export-NonComplianceReports`

Exports Non-Compliance Reports in CSV format

```ps1
Export-NonComplianceReports [[-PacEnvironmentSelector] <String>] [-DefinitionsRootFolder <String>] [-OutputFolder <String>] [-WindowsNewLineCells] [-Interactive <Boolean>] [-OnlyCheckManagedAssignments] [-PolicyDefinitionFilter <String[]>] [-PolicySetDefinitionFilter <String[]>] [-PolicyAssignmentFilter <String[]>] [-PolicyEffectFilter <String[]>] [-ExcludeManualPolicyEffect] [-RemediationOnly] [<CommonParameters>]
```

### Parameters

#### `-PacEnvironmentSelector <String>`

Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

#### `-DefinitionsRootFolder <String>`

        Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

#### `-OutputFolder <String>`

Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

#### `-WindowsNewLineCells [<SwitchParameter>]`

Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell

#### `-Interactive <Boolean>`

Set to false if used non-interactive

#### `-OnlyCheckManagedAssignments [<SwitchParameter>]`

Include non-compliance data only for Policy assignments owned by this Policy as Code repo

#### `-PolicyDefinitionFilter <String[]>`

Filter by Policy definition names (array) or ids (array).

#### `-PolicySetDefinitionFilter <String[]>`

Filter by Policy Set definition names (array) or ids (array).

#### `-PolicyAssignmentFilter <String[]>`

Filter by Policy Assignment names (array) or ids (array).

#### `-PolicyEffectFilter <String[]>`

Filter by Policy Effect (array).

#### `-ExcludeManualPolicyEffect [<SwitchParameter>]`

Switch parameter to filter out Policy Effect Manual

#### `-RemediationOnly [<SwitchParameter>]`

Filter by Policy Effect "deployifnotexists" and "modify" and compliance status "NonCompliant"

## Script `Get-AzExemptions`

Retrieves Policy Exemptions from an EPAC environment and saves them to files.

```ps1
Get-AzExemptions [[-PacEnvironmentSelector] <String>] [-DefinitionsRootFolder <String>] [-OutputFolder <String>] [-Interactive <Boolean>] [-FileExtension <String>] [-ActiveExemptionsOnly] [<CommonParameters>]
```

### Parameters

#### `-PacEnvironmentSelector <String>`

Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

#### `-DefinitionsRootFolder <String>`

Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

#### `-OutputFolder <String>`

Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

#### `-Interactive <Boolean>`

Set to false if used non-interactive

#### `-FileExtension <String>`

File extension type for the output files. Valid values are json or jsonc. The default output file is json.

#### `-ActiveExemptionsOnly [<SwitchParameter>]`

Set to true to only generate files for active (not expired and not orphaned) exemptions. Defaults to false.

## Script `Get-AzMissingTags`

Gets all resources that are missing tags in the current subscription.

```ps1
Get-AzMissingTags [[-PacEnvironmentSelector] <String>] [-DefinitionsRootFolder <String>] [-OutputFileName <String>] [-Interactive <Boolean>] [<CommonParameters>]
```

### Parameters

#### `-PacEnvironmentSelector <String>`

Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

#### `-DefinitionsRootFolder <String>`

Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

#### `-OutputFileName <String>`

Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv or './Outputs/Tags/missing-tags-results.csv'.

#### `-Interactive <Boolean>`

Set to false if used non-interactive

## Script `Get-AzPolicyAliasOutputCSV`

Gets all aliases and outputs them to a CSV file.

```ps1
Get-AzPolicyAliasOutputCSV [<CommonParameters>]
```

## Script `New-AzPolicyReaderRole`

Creates a custom role 'Policy Reader' that provides read access to all Policy resources to plan the EPAC deployments.

```ps1
New-AzPolicyReaderRole [[-PacEnvironmentSelector] <String>] [-DefinitionsRootFolder <String>] [-Interactive <Boolean>] [<CommonParameters>]
```

### Parameters

#### `-PacEnvironmentSelector <String>`

Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

#### `-DefinitionsRootFolder <String>`

    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

#### `-Interactive <Boolean>`

Set to false if used non-interactive

## Script `New-HydrationDefinitionFolder`

Creates a definitions folder with the correct folder structure and blank global settings file.

```ps1
New-HydrationDefinitionFolder [[-DefinitionsRootFolder] <String>] [<CommonParameters>]
```

### Description

Creates a definitions folder with the correct folder structure and blank global settings file.

### Parameters

#### `-DefinitionsRootFolder <String>`

The folder path to create the definitions root folder (./Definitions)

## Script `New-EpacGlobalSettings`

Creates a global-settings.jsonc file with a new GUID, managed identity location and tenant information

```ps1
New-EpacGlobalSettings [-ManagedIdentityLocation] <String> [-TenantId] <String> [-DefinitionsRootFolder] <String> [-DeploymentRootScope] <String> [<CommonParameters>]
```

### Parameters

#### `-ManagedIdentityLocation <String>`

The Azure location to store the managed identities (Get-AzLocation|Select Location)

#### `-TenantId <String>`

The Azure tenant id

#### `-DefinitionsRootFolder <String>`

The folder path to where the New-EpacDefinitionsFolder command created the definitions root folder (C:\definitions\)

#### `-DeploymentRootScope <String>`

The root management group to export definitions and assignments (/providers/Microsoft.Management/managementGroups/)

## Script `New-EpacPolicyAssignmentDefinition`

Exports a policy assignment from Azure to a local file in the EPAC format.

```ps1
New-EpacPolicyAssignmentDefinition [-PolicyAssignmentId] <String> [[-OutputFolder] <String>] [<CommonParameters>]
```

### Parameters

#### `-PolicyAssignmentId <String>`

The policy assignment id

#### `-OutputFolder <String>`

The folder path for the Policy Assignment.

## Script `New-EpacPolicyDefinition`

Exports a Policy definition from Azure to a local file in the EPAC format

```ps1
New-EpacPolicyDefinition [-PolicyDefinitionId] <String> [[-OutputFolder] <String>] [<CommonParameters>]
```

### Parameters

#### `-PolicyDefinitionId <String>`

The Policy definition id.

#### `-OutputFolder <String>`

The folder path for the Policy Definition.

## Script `New-PipelineFromStarterKit`

This script copies pipelines and templates from the starter kit to a new folder. The script assembles the pipelines/workflows based on the type of pipeline to create, the branching flow to implement, and the type of script to use.

```ps1
New-PipelineFromStarterKit [[-StarterKitFolder] <String>] [[-PipelinesFolder] <String>] [[-PipelineType] <String>] [[-BranchingFlow] <String>] [[-ScriptType] <String>] [<CommonParameters>]
```

### Parameters

#### `-StarterKitFolder <String>`

Starter kit folder

#### `-PipelinesFolder <String>`

New pipeline folder

#### `-PipelineType <String>`

Type of DevOps pipeline to create AzureDevOps or GitHubActions?

#### `-BranchingFlow <String>`

Implementing branching flow Release or GitHub

#### `-ScriptType <String>`

Using Powershell module or script?
