#Requires -PSEdition Core

[CmdletBinding()]
param ()

$InformationPreference = "Continue"
. "$PSScriptRoot/../Config/Initialize-Environment.ps1"
. "$PSScriptRoot/../Config/Get-AzEnvironmentDefinitions.ps1"
$environmentDefinitions = Get-AzEnvironmentDefinitions
$environment = $environmentDefinitions | Initialize-Environment

. "$PSScriptRoot/../Deploy/Build-AzPoliciesInitiativesAssignmentsPlan.ps1" `
    -InformationAction Continue `
    -TenantId $environment["tenantID"] `
    -RootScope $environment["rootScope"] `
    -AssignmentSelector $environment["assignmentSelector"] `
    -PlanFile $environment["planFile"]
