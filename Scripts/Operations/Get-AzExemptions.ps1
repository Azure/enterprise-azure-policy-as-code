<#
.SYNOPSIS
    Retrieves Policy Exemptions from an EPAC environment and saves them to files.

.PARAMETER PacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.    

.PARAMETER DefinitionsRootFolder    
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFolder
    Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

.PARAMETER Interactive
    Set to false if used non-interactive

.PARAMETER FileExtension
    File extension type for the output files. Valid values are json and jsonc. Defaults to json.

.EXAMPLE
    .\Get-AzExemptions.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFolder "C:\Src\Outputs" -Interactive $true -FileExtension "jsonc"
    Retrieves Policy Exemptions from an EPAC environment and saves them to files.

.EXAMPLE
    .\Get-AzExemptions.ps1 -Interactive $true
    Retrieves Policy Exemptions from an EPAC environment and saves them to files. The script prompts for the PAC environment and uses the default definitions and output folders.

.LINK
    https://azure.github.io/enterprise-azure-policy-as-code/policy-exemptions/
#>
[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true,

    [ValidateSet("json", "jsonc")]
    [Parameter(Mandatory = $false, HelpMessage = "File extension type for the output files. Defaults to '.jsonc'.")]
    [string] $FileExtension = "json"
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive
$policyExemptionsFolder = "$($pacEnvironment.outputFolder)/policyExemptions"

$scopeTable = Get-AzScopeTree -PacEnvironment $pacEnvironment
$deployedPolicyResources = Get-AzPolicyResources -PacEnvironment $pacEnvironment -ScopeTable $scopeTable -SkipRoleAssignments
$exemptions = $deployedPolicyResources.policyExemptions.managed
$assignments = $deployedPolicyResources.policyassignments.managed

Out-PolicyExemptions `
    -Exemptions $exemptions `
    -Assignments $assignments `
    -PolicyExemptionsFolder $policyExemptionsFolder `
    -OutputJson `
    -OutputCsv `
    -ExemptionOutputType "*" `
    -FileExtension $FileExtension
