#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(Mandatory = $false, Position = 0)] [string] $environmentSelector = $null
)

$InformationPreference = "Continue"
. "$PSScriptRoot/../Config/Initialize-Environment.ps1"
. "$PSScriptRoot/../Config/Get-AzEnvironmentDefinitions.ps1"

$environment, $defaultSubscriptionId = Initialize-Environment $environmentSelector

if ($environment["assignmentSelector"] -eq "PROD") {
    throw "You are not allowed to execuute deployment script to PROD environemnt manually"
}

. "$PSScriptRoot/../Deploy/Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1" `
    -InformationAction Continue `
    -PlanFile $environment["planFile"] `
    -RolesPlanFile $environment["rolesPlan"]
