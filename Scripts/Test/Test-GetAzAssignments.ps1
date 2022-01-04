#Requires -PSEdition Core

[CmdletBinding()]
param()

. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Utils/Split-AzPolicyAssignmentIdForAzCli.ps1"

$InformationPreference = "Continue"
. "$PSScriptRoot/../Config/Initialize-Environment.ps1"
. "$PSScriptRoot/../Config/Get-AzEnvironmentDefinitions.ps1"
$environmentDefinitions = Get-AzEnvironmentDefinitions
$environment = $environmentDefinitions | Initialize-Environment

$globalSettingsFile = "$PSScriptRoot/../../Definitions/global-settings.jsonc"
$globalNotScopeList, $managedIdentityLocation = Get-GlobalSettings -AssignmentSelector $environment["assignmentSelector"] -GlobalSettingsFile $globalSettingsFile

$scopeTreeInfo = Get-AzScopeTree -tenantId $environment["tenantID"] -scopeParam $environment["scopeParam"]

$collections = Get-AllAzPolicyInitiativeDefinitions -RootScope $environment["rootScope"]
$allPolicyDefinitions = $collections.builtInPolicyDefinitions + $collections.existingCustomPolicyDefinitions
$allInitiativeDefinitions = $collections.builtInInitiativeDefinitions + $collections.existingCustomInitiativeDefinitions

$assignments, $remediations = Get-AzAssignmentsAtScopeRecursive -scopeTreeInfo $scopeTreeInfo -notScopeIn $globalNotScopeList `
    -includeResourceGroups $false -getAssignments $true -getRemediations $true `
    -allPolicyDefinitions $allPolicyDefinitions -allInitiativeDefinitions $allInitiativeDefinitions

@{
    scopeTreeInfo = $scopeTreeInfo
    assignments   = $assignments
    remediations  = $remediations
} | ConvertTo-Json -Depth 100 | Out-File "$PSScriptRoot/../../Output/assignments-$($environment.assignmentSelector).json"
