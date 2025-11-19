function Get-AzExemptions {
<#
    Retrieves Policy Exemptions from an EPAC environment and saves them to files.

    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.    

    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

    Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

    Set to false if used non-interactive

    File extension type for the output files. Valid values are json and jsonc. Defaults to json.

    Set to true to only generate files for active (not expired and not orphaned) exemptions. Defaults to false.

    .\Get-AzExemptions.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFolder "C:\Src\Outputs" -Interactive $true -FileExtension "jsonc"
    Retrieves Policy Exemptions from an EPAC environment and saves them to files.

    .\Get-AzExemptions.ps1 -Interactive $true
    Retrieves Policy Exemptions from an EPAC environment and saves them to files. The script prompts for the PAC environment and uses the default definitions and output folders.

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
    [string] $FileExtension = "json",

    [Parameter(Mandatory = $false, HelpMessage = "Set to true to only generate files for active (not expired and not orphaned) exemptions. Defaults to false.")]
    [switch] $ActiveExemptionsOnly
)

# Dot Source Helper Scripts

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive
$policyExemptionsFolder = "$($pacEnvironment.outputFolder)/policyExemptions"

Write-ModernHeader -Title "Retrieving Policy Exemptions" -Subtitle $($pacEnvironment.displayName)

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-ModernStatus -Message "Telemetry is enabled" -Status "info" -Indent 2
    Submit-EPACTelemetry -Cuapid "pid-3f02e7d5-1cf5-490a-a95c-3d49f0673093" -DeploymentRootScope $pacEnvironment.deploymentRootScope
}
else {
    Write-ModernStatus -Message "Telemetry is disabled" -Status "info" -Indent 2
}

Write-ModernSection -Title "Loading Azure Policy Resources" -Indent 0
$scopeTable = Build-ScopeTableForDeploymentRootScope -PacEnvironment $pacEnvironment
$deployedPolicyResources = Get-AzPolicyResources -PacEnvironment $pacEnvironment -ScopeTable $scopeTable -SkipRoleAssignments
$exemptions = $deployedPolicyResources.policyExemptions.managed

Write-ModernSection -Title "Generating Exemption Reports" -Indent 0

Out-PolicyExemptions `
    -PacEnvironment $pacEnvironment `
    -Exemptions $exemptions `
    -PolicyExemptionsFolder $policyExemptionsFolder `
    -OutputJson `
    -OutputCsv `
    -FileExtension $FileExtension `
    -ActiveExemptionsOnly:$ActiveExemptionsOnly
}
