<#
.SYNOPSIS
    Creates a custom role 'Policy Reader' that provides read access to all Policy resources for the purpose of planning the EPAC deployments.

.PARAMETER PacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER Interactive
    Set to false if used non-interactive

.EXAMPLE
    .\New-AzPolicyReaderRole.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -Interactive $true
    Creates a custom role 'Policy Reader' that provides read access to all Policy resources for the purpose of planning the EPAC deployments.

.EXAMPLE
    .\New-AzPolicyReaderRole.ps1 -Interactive $true
    Creates a custom role 'Policy Reader' that provides read access to all Policy resources for the purpose of planning the EPAC deployments. The script prompts for the PAC environment and uses the default definitions and output folders.
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -Interactive $pacEnvironment.interactive

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("pid-f4b5b7ac-70b4-40fc-836f-585791aa83e7") 
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

# Get the root scope for the Policy Definitions
$policyDefinitionsScopes = $pacEnvironment.policyDefinitionsScopes
$deploymentRootScope = $policyDefinitionsScopes[0]


Write-Information "==================================================================================================="
Write-Information "Creating custom role 'Policy Reader'"
Write-Information "==================================================================================================="


$role = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition]::new()
$role.Name = 'EPAC Resource Policy Reader'
$role.Id = '2baa1a7c-6807-46af-8b16-5e9d03fba029'
$role.Description = 'Provides read access to all Policy resources for the purpose of planning the EPAC deployments.'
$role.IsCustom = $true
$perms = @(
    "Microsoft.Authorization/policyassignments/read",
    "Microsoft.Authorization/policydefinitions/read",
    "Microsoft.Authorization/policyexemptions/read",
    "Microsoft.Authorization/policysetdefinitions/read",
    "Microsoft.PolicyInsights/*",
    "Microsoft.Management/register/action",
    "Microsoft.Management/managementGroups/read"
)

$role.Actions = $perms
$role.NotActions = $()
$role.AssignableScopes = $deploymentRootScope
New-AzRoleDefinition -Role $role
