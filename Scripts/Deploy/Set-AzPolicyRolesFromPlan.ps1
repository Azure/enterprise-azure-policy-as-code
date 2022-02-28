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
    [string]$PlanFile = "./Plans/roles.json"
)

Write-Information "==================================================================================================="
Write-Information "Updating Role Assignments"
Write-Information "==================================================================================================="
Write-Information ""

. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Utils/Split-AzPolicyAssignmentIdForAzCli.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"

Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput

$plan = Get-DeploymentPlan -PlanFile $PlanFile

$removedRoleAssignments = $plan.removed | ConvertTo-HashTable
$addedRoleAssignments = $plan.added | ConvertTo-HashTable
$changesNeeded = $removedRoleAssignments.Count -gt 0 -or $addedRoleAssignments.Count -gt 0

if ($changesNeeded) {
    if ($removedRoleAssignments.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Remove ($($removedRoleAssignments.Count)) obsolete Role assignements"
        Write-Information "---------------------------------------------------------------------------------------------------"

        foreach ($assignmentId in $removedRoleAssignments.Keys) {
            $assignment = $removedRoleAssignments[$assignmentId]
            $identity = $assignment.identity
            $roleAssignments = $assignment.roleAssignments
            Write-Information "'$($assignmentId)' - '$($assignment.DisplayName)'"
            Write-Information "        PrincipaId: $($identity.principalId)"
            foreach ($roleAssignment in $roleAssignments) {
                $scope = $roleAssignment.scope
                $roleDefinitionId = $roleAssignment.roleDefinitionId
                $roleDefinitionName = $roleAssignment.roleDefinitionName
                Write-Information "    $($roleDefinitionName) - $($roleDefinitionId), Scope=$($scope), Role Assignment Id=$($roleAssignment.id)"
                Invoke-AzCli role assignment delete --ids $roleAssignment.id -SuppressOutput
            }
        }
        Write-Information ""
    }

    if ($addedRoleAssignments.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Add ($($addedRoleAssignments.Count)) new Role assignements"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $retriesLimit = 4
        foreach ($assignmentId in $addedRoleAssignments.Keys) {
            $assignment = $addedRoleAssignments[$assignmentId]
            $identity = $assignment.identity
            $roles = $assignment.roles
            Write-Information "'$($assignmentId)' - '$($assignment.DisplayName)'"
            Write-Information "        PrincipaId: $($identity.PrincipalId)"
            foreach ($role in $roles) {
                $scope = $role.scope
                $roleDefinitionId = $role.roleDefinitionId
                $roleDefinitionName = $role.roleDefinitionName
                Write-Information "    $($roleDefinitionName) - $($roleDefinitionId), Scope=$($scope)"

                $retries = 0
                while ($retries -le $retriesLimit) {
                    $result = az role assignment create --role $roleDefinitionName --assignee-object-id $identity.principalId --assignee-principal-type ServicePrincipal --scope $scope
                    if ($result) {
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
}
else {
    Write-Information "***************************** NO CHANGES NEEDED ***************************************************"
}
