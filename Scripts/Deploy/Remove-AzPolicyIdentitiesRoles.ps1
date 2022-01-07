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
    [Parameter(Mandatory = $false,
        HelpMessage = "Plan input filename.")]
    [string]$PlanFile = "./Plans/current.json"
)

. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Utils/Split-AzPolicyAssignmentIdForAzCli.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"

$plan = Get-DeploymentPlan -PlanFile $PlanFile

$removedRoleAssignments = $plan.removedRoleAssignments | ConvertTo-HashTable
$removedIdentities = $plan.removedIdentities | ConvertTo-HashTable
$changesNeeded = $assignments.Count -ne 0 -or $identities.Count -ne 0

if ($changesNeeded) {
    Write-Information "==================================================================================================="
    Write-Information "Remove Obsolete Idenities and Role assignemnts ""$PlanFile"""
    Write-Information "==================================================================================================="

    Write-Information "Remove obsolete Role Assignments ($($removedRoleAssignments.Count))"
    foreach ($assignmentId in $removedRoleAssignments.Keys) {
        $assignment = $removedRoleAssignments[$assignmentId]
        $roleAssignments = $assignment.roleAssignments
        Write-Information "    ""$($assignmentId)"" - ""$($assignment.DisplayName)"""
        foreach ($roleAssignment in $roleAssignments) {
            Write-Information "        Scope=$($roleAssignment.scope), Role=$($roleAssignment.roleDefinitionName)"
            Invoke-AzCli role assignment delete --ids $roleAssignment.id -SuppressOutput
        }
    }

    Write-Information "Remove unnecessary Identities ($($removedIdentities.Count))"
    foreach ($assignmentId in $removedIdentities.Keys) {
        $assignment = $assignments[$assignmentId]
        Write-Information "    ""$($assignmentId)"" - ""$($assignment.DisplayName)"""
        $splat = Split-AzPolicyAssignmentIdForAzCli -id $assignmentId
        Invoke-AzCli policy assignment identity remove -Splat $splat -SuppressOutput
    }
    Write-Information ""
    Write-Information ""
}
