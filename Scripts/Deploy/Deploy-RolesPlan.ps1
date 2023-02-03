#Requires -PSEdition Core

<#
.SYNOPSIS
    This script deploys the component as defined in the plan JSON:

.NOTES
    This script is designed to be run in Azure DevOps pipelines.
    Version:        1.0
    Creation Date:  2021-08-03
#>

[CmdletBinding()]
param (
    [parameter(HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.",
        Position = 0
    )]
    [string] $pacEnvironmentSelector,

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder,

    [Parameter(HelpMessage = "Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$inputFolder,

    [Parameter(HelpMessage = "Use switch to indicate interactive use")]
    [switch] $interactive
)

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Split-ScopeId.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $pacEnvironmentSelector -definitionsRootFolder $definitionsRootFolder -inputFolder $inputFolder  -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive

$planFile = $pacEnvironment.rolesPlanInputFile
$plan = Get-DeploymentPlan -planFile $planFile -asHashTable

if ($null -eq $plan) {
    Write-Warning "***************************************************************************************************"
    Write-Warning "Plan does not exist, skip Role assignments deployment."
    Write-Warning "***************************************************************************************************"
    Write-Warning ""
}
else {

    Write-Information "***************************************************************************************************"
    Write-Information "Deploy Role assignments from plan in file '$planFile'"
    Write-Information "Plan created on $($plan.createdOn)."
    Write-Information "***************************************************************************************************"

    $removedRoleAssignments = $plan.roleAssignments.removed
    $addedRoleAssignments = $plan.roleAssignments.added
    if ($removedRoleAssignments.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Remove ($($removedRoleAssignments.Count)) obsolete Role assignments"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $splatTransform = "principalId/ObjectId scope/Scope roleDefinitionId/RoleDefinitionId"
        foreach ($roleAssignment in $removedRoleAssignments) {
            Write-Information "$($roleAssignment.displayName): $($roleAssignment.roleDisplayName)($($roleAssignment.roleDefinitionId)) at $($roleAssignment.scope)"
            $splat = Get-FilteredHashTable $roleAssignment -splatTransform $splatTransform
            $null = Remove-AzRoleAssignment @splat -WarningAction SilentlyContinue
        }
        Write-Information ""
    }

    if ($addedRoleAssignments.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Add ($($addedRoleAssignments.Count)) new Role assignments"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $retriesLimit = 4
        $splatTransform = "principalId/ObjectId objectType/ObjectType scope/Scope roleDefinitionId/RoleDefinitionId"
        $identitiesByAssignmentId = @{}
        foreach ($roleAssignment in $addedRoleAssignments) {
            $principalId = $roleAssignment.principalId
            if ($null -eq $principalId) {
                $policyAssignmentId = $roleAssignment.assignmentId
                $identity = $null
                if ($identitiesByAssignmentId.ContainsKey($policyAssignmentId)) {
                    $identity = $identitiesByAssignmentId.$policyAssignmentId
                }
                else {
                    $policyAssignment = Get-AzPolicyAssignment -Id $roleAssignment.assignmentId -WarningAction SilentlyContinue
                    $identity = $policyAssignment.Identity
                    $null = $identitiesByAssignmentId.Add($policyAssignmentId, $identity)
                }
                $principalId = $identity.PrincipalId
                $roleAssignment.principalId = $principalId
            }
            Write-Information "$($policyAssignment.Properties.displayName): $($roleAssignment.roleDisplayName)($($roleAssignment.roleDefinitionId)) at $($roleAssignment.scope)"
            $splat = Get-FilteredHashTable $roleAssignment -splatTransform $splatTransform

            while ($retries -le $retriesLimit) {

                $result = New-AzRoleAssignment @splat -WarningAction SilentlyContinue
                if ($null -ne $result) {
                    break
                }
                else {
                    Start-Sleep -Seconds 10
                    $retries++
                }
            }
        }
    }
    Write-Information ""
}
