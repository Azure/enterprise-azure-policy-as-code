#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector = ""
)

. "$PSScriptRoot/../Deploy/Build-AzPoliciesInitiativesAssignmentsPlan.ps1" `
    -InformationAction Continue `
    -PacEnvironmentSelector  $PacEnvironmentSelector `
    -TestInitiativeMerge
