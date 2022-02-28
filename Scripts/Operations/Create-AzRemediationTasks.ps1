#Requires -PSEdition Core

[CmdletBinding()]
param(
    [switch] $suppressCollectionInformation,
    [switch] $suppressCreateInformation,
    [parameter(Mandatory = $False)] [string] $environmentSelector = ""
)

. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Utils/Split-AzPolicyAssignmentIdForAzCli.ps1"
. "$PSScriptRoot/../Config/Initialize-Environment.ps1"
. "$PSScriptRoot/../Config/Get-AzEnvironmentDefinitions.ps1"

if ($suppressCollectionInformation.IsPresent) {
    $InformationPreference = "SilentContinue"
}
else {
    $InformationPreference = "Continue"
}

$environmentDefinitions = Get-AzEnvironmentDefinitions
$environment = $environmentDefinitions | Initialize-Environment -environmentSelector $environmentSelector

if ($suppressCollectionInformation.IsPresent) {
    $InformationPreference = "SilentContinue"
}
else {
    $InformationPreference = "Continue"
}


$globalSettingsFile = "$PSScriptRoot/../../Definitions/global-settings.jsonc"
$globalNotScopeList, $managedIdentityLocation = Get-GlobalSettings -AssignmentSelector $environment["assignmentSelector"] -GlobalSettingsFile $globalSettingsFile

$scopeTreeInfo = Get-AzScopeTree -tenantId $environment["tenantID"] -scopeParam $environment["scopeParam"]

$collections = Get-AllAzPolicyInitiativeDefinitions -RootScope $environment["rootScope"]
$allPolicyDefinitions = $collections.builtInPolicyDefinitions + $collections.existingCustomPolicyDefinitions
$allInitiativeDefinitions = $collections.builtInInitiativeDefinitions + $collections.existingCustomInitiativeDefinitions

$null, $remediations = Get-AzAssignmentsAtScopeRecursive `
    -scopeTreeInfo $scopeTreeInfo `
    -notScopeIn $globalNotScopeList `
    -includeResourceGroups $false `
    -getAssignments $false `
    -getRemediations $true `
    -allPolicyDefinitions $allPolicyDefinitions `
    -allInitiativeDefinitions $allInitiativeDefinitions

if ($suppressCreateInformation.IsPresent) {
    $InformationPreference = "SilentContinue"
}
else {
    $InformationPreference = "Continue"
}

if ($remediations.Count -lt 1) {
    Write-Information "==================================================================================================="
    Write-Information "No Remediation Tasks - zero resources need remediation"
    Write-Information "==================================================================================================="

}
else {
    Write-Information "==================================================================================================="
    Write-Information "Creating Remediation Tasks"
    Write-Information "==================================================================================================="

    foreach ($scope in $remediations.Keys) {
        $assignments = $remediations[$scope]
        Write-Information "Scope $scope"
        foreach ($assignmentId in $assignments.Keys) {
            $assignment = $assignments[$assignmentId]
            $remediationTaskDefinitions = $assignment.remediationTasks
            Write-Information "    Assignment ""$($assignment.assignmentDisplayName)"", Resources=$($assignment.nonCompliantResources)"
            if ($assignment.initiativeId -ne "") {
                Write-Information "        Assigned Initiative ""$($assignment.initiativeName)"""
            }
            foreach ($remediationTaskDefinition in $remediationTaskDefinitions) {
                $info = $remediationTaskDefinition.info
                Write-Information "        Policy=""$($info.policyDisplayName)"", Resources=$($info.nonCompliantResources)"
                Invoke-AzCli policy remediation create -Splat $remediationTaskDefinition.splat -SuppressOutput
            }
        }
        Write-Information "---------------------------------------------------------------------------------------------------"
    }
}
Write-Information ""
