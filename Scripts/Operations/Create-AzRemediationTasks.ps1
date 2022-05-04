#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a vlaue. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder
)

. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Helpers/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Helpers/Split-AzPolicyAssignmentIdForAzCli.ps1"

$InformationPreference = "Continue"
$environment = Initialize-Environment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder
$rootScopeId = $environment.rootScopeId
$rootScope = $environment.rootScope

$collections = Get-AllAzPolicyInitiativeDefinitions -rootScopeId $rootScopeId
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
