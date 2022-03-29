#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector,
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable PacDefinitionsRootFolder or './Definitions'.")] [string]$DefinitionsRootFolder
)

$InformationPreference = "Continue"
$environment = Initialize-Environment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder
if ($environment.pacSelector -eq "prod") {
    throw "You are not allowed to execuute deployment script to PROD environemnt manually"
}

. "$PSScriptRoot/../Deploy/Set-AzPolicyRolesFromPlan.ps1" `
    -InformationAction Continue `
    -RolesPlanFile $environment.rolesFile
