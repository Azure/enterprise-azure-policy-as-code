#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector = "",
    [Parameter(Mandatory = $false, HelpMessage = "Global settings filename.")]
    [string]$GlobalSettingsFile = "./Definitions/global-settings.jsonc"
)

$InformationPreference = "Continue"
$environment = Initialize-Environment $PacEnvironmentSelector -GlobalSettingsFile $GlobalSettingsFile
if ($environment.pacSelector -eq "prod") {
    throw "You are not allowed to execuute deployment script to PROD environemnt manually"
}

. "$PSScriptRoot/../Deploy/Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1" `
    -InformationAction Continue `
    -PlanFile $environment.planFile `
    -RolesPlanFile $environment.roleFile
