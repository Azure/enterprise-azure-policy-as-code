<#
.SYNOPSIS
    Retrieves Policy Exemptions from an EPAC environment and saves them to files.

.PARAMETER pacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.    

.PARAMETER definitionsRootFolder    
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER outputFolder
    Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

.PARAMETER interactive
    Set to false if used non-interactive

.PARAMETER fileExtension
    File extension type for the output files. Valid values are json and jsonc. Defaults to json.

.EXAMPLE
    .\Get-AzExemptions.ps1 -pacEnvironmentSelector "dev" -definitionsRootFolder "C:\Src\Definitions" -outputFolder "C:\Src\Outputs" -interactive $true -fileExtension "jsonc"
    Retrieves Policy Exemptions from an EPAC environment and saves them to files.

.EXAMPLE
    .\Get-AzExemptions.ps1 -interactive $true
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
    [bool] $interactive = $true,

    [ValidateSet("json", "jsonc")]
    [Parameter(Mandatory = $false, HelpMessage = "File extension type for the output files. Defaults to '.jsonc'.")]
    [string] $fileExtension = "json"
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive
$policyExemptionsFolder = "$($pacEnvironment.outputFolder)/policyExemptions"

$scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
$deployedPolicyResources = Get-AzPolicyResources -pacEnvironment $pacEnvironment -scopeTable $scopeTable -skipRoleAssignments
$exemptions = $deployedPolicyResources.policyExemptions.managed
$assignments = $deployedPolicyResources.policyassignments.managed

Out-PolicyExemptions `
    -exemptions $exemptions `
    -assignments $assignments `
    -policyExemptionsFolder $policyExemptionsFolder `
    -outputJson `
    -outputCsv `
    -exemptionOutputType "*" `
    -fileExtension $fileExtension
