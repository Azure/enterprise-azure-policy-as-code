#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector = "",
    [Parameter(Mandatory = $false, HelpMessage = "Global settings filename.")]
    [string]$GlobalSettingsFile = "./Definitions/global-settings.jsonc"
)

. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Utils/Split-AzPolicyAssignmentIdForAzCli.ps1"

$environment = Initialize-Environment $PacEnvironmentSelector -GlobalSettingsFile $GlobalSettingsFile
$rootScope = $environment.rootScope

$collections = Get-AllAzPolicyInitiativeDefinitions -RootScope $rootScope
$allPolicyDefinitions = $collections.builtInPolicyDefinitions + $collections.existingCustomPolicyDefinitions
$allInitiativeDefinitions = $collections.builtInInitiativeDefinitions + $collections.existingCustomInitiativeDefinitions

$scopeTreeInfo = Get-AzScopeTree `
    -tenantId $environment.tenantId `
    -scopeParam $rootScope `
    -defaultSubscriptionId $environment.defaultSubscriptionId
$null, $remediations = Get-AzAssignmentsAtScopeRecursive `
    -scopeTreeInfo $scopeTreeInfo `
    -notScopeIn $environment.globalNotScopeList `
    -includeResourceGroups $false `
    -getAssignments $false `
    -getRemediations $true `
    -allPolicyDefinitions $allPolicyDefinitions `
    -allInitiativeDefinitions $allInitiativeDefinitions

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
            # Write-Information "    Assignment ""$($assignment.assignmentDisplayName)"", Resources=$($assignment.nonCompliantResources)"
            if ($assignment.initiativeId -ne "") {
                # Write-Information "        Assigned Initiative ""$($assignment.initiativeDisplayName)"""
            }
            foreach ($remediationTaskDefinition in $remediationTaskDefinitions) {
                $info = $remediationTaskDefinition.info
                Write-Information "    Policy=""$($info.policyDisplayName)"", Resources=$($info.nonCompliantResources)"
                Invoke-AzCli policy remediation create -Splat $remediationTaskDefinition.splat -SuppressOutput
            }
        }
        Write-Information "---------------------------------------------------------------------------------------------------"
    }
}
Write-Information ""
