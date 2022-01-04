#Requires -PSEdition Core

[CmdletBinding()]
param ()

$InformationPreference = "Continue"
. "$PSScriptRoot/../Config/Initialize-Environment.ps1"
. "$PSScriptRoot/../Config/Get-AzEnvironmentDefinitions.ps1"
$environmentDefinitions = Get-AzEnvironmentDefinitions
$environment = $environmentDefinitions | Initialize-Environment

# if ($environment["assignmentSelector"] -eq "PROD") {
#     throw "You are not allowed to execuute deployment script to PROD environemnt manually"
# }

. "$PSScriptRoot/../Deploy/Remove-AzPolicyIdentitiesRoles.ps1" `
    -InformationAction Continue `
    -PlanFile $environment["planFile"]

. "$PSScriptRoot/../Deploy/Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1" `
    -InformationAction Continue `
    -PlanFile $environment["planFile"]