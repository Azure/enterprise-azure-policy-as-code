[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true
)

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

$InformationPreference = "Continue"
Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive

Write-Information "==================================================================================================="
Write-Information "Creating custom role 'EPAC Policy Reader'"
Write-Information "==================================================================================================="


$role = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition]::new()
$role.Name = 'EPAC Policy Reader'
$role.Id = '2baa1a7c-6807-46af-8b16-5e9d03fba029'
$role.Description = 'Read access to Azure Policy.'
$role.IsCustom = $true
$perms = @(
    "*/read",
    "Microsoft.Authorization/policyassignments/read",
    "Microsoft.Authorization/policydefinitions/read",
    "Microsoft.Authorization/policyexemptions/read",
    "Microsoft.Authorization/policysetdefinitions/read",
    "Microsoft.PolicyInsights/*",
    "Microsoft.Support/*"
)

$role.Actions = $perms
$role.NotActions = $()
$role.AssignableScopes = $pacEnvironment.rootScopeId
New-AzRoleDefinition -Role $role
