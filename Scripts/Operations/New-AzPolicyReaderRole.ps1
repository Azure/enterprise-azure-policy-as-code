[CmdletBinding()]
param(
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector = "",
    [Parameter(Mandatory = $false, HelpMessage = "Global settings filename.")] [string]$GlobalSettingsFile = "./Definitions/global-settings.jsonc"
)

. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"

$environment = Initialize-Environment $PacEnvironmentSelector -GlobalSettingsFile $GlobalSettingsFile

Write-Information "==================================================================================================="
Write-Information "Creating custom role 'Policy Reader'"
Write-Information "==================================================================================================="


$role = [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition]::new()
$role.Name = 'Policy Reader'
$role.Id = '2baa1a7c-6807-46af-8b16-5e9d03fba029'
$role.Description = 'Read access to Azure Policy.'
$role.IsCustom = $true
$perms = @( 
    "Microsoft.Authorization/policyAssignments/read",
    "Microsoft.Authorization/policyDefinitions/read",
    "Microsoft.Authorization/policySetDefinitions/read"
)

$role.Actions = $perms
$role.NotActions = $()
$role.AssignableScopes = $environment.rootScopeId
New-AzRoleDefinition -Role $role
