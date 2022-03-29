[CmdletBinding()]
param(
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector,
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable PacDefinitionsRootFolder or './Definitions'.")] [string]$DefinitionsRootFolder
)

. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"

$InformationPreference = "Continue"
$environment = Initialize-Environment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder

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
