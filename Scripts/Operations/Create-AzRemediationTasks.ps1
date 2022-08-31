#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true
)

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Helpers/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Helpers/Split-AssignmentIdForAzCli.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

$InformationPreference = "Continue"
Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive

$rootScopeId = $pacEnvironment.rootScopeId
$rootScope = $pacEnvironment.rootScope

$allAzPolicyInitiativeDefinitions = Get-AzPolicyInitiativeDefinitions -rootScope $rootScope -rootScopeId $rootScopeId
$allPolicyDefinitions = $allAzPolicyInitiativeDefinitions.builtInPolicyDefinitions + $allAzPolicyInitiativeDefinitions.existingCustomPolicyDefinitions
$allInitiativeDefinitions = $allAzPolicyInitiativeDefinitions.builtInInitiativeDefinitions + $allAzPolicyInitiativeDefinitions.existingCustomInitiativeDefinitions

$scopeTreeInfo = Get-AzScopeTree `
    -tenantId $pacEnvironment.tenantId `
    -scopeParam $rootScope `
    -defaultSubscriptionId $pacEnvironment.defaultSubscriptionId
$null, $remediations, $null = Get-AzAssignmentsAtScopeRecursive `
    -scopeTreeInfo $scopeTreeInfo `
    -notScopeIn $pacEnvironment.globalNotScopeList `
    -includeResourceGroups $false `
    -getAssignments $false `
    -getExemptions $false `
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
