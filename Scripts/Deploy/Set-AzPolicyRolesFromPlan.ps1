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
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$InputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Role Assignment plan input filename. Defaults to `$InputFolder/roles-plan-`$PacEnvironmentSelector/roles-plan.json.")]
    [string] $RolesPlanFile,

    [Parameter(Mandatory = $false, HelpMessage = "Use switch to indicate interactive use")] [switch] $interactive
)

Write-Information "==================================================================================================="
Write-Information "Updating Role Assignments"
Write-Information "==================================================================================================="
Write-Information ""

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Helpers/Split-AssignmentIdForAzCli.ps1"
. "$PSScriptRoot/../Helpers/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

$InformationPreference = "Continue"
Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive.IsPresent
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive
if ($RolesPlanFile -eq "") {
    $RolesPlanFile = $pacEnvironment.rolesPlanInputFile
}
$plan = Get-DeploymentPlan -PlanFile $RolesPlanFile

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
                $roleDisplayName = $roleAssignment.roleDisplayName
                Write-Information "    $($roleDisplayName) - $($roleDefinitionId), Scope=$($scope), Role Assignment Id=$($roleAssignment.id)"
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
                $roleDefinitionName = $roleDefinitionId.Split('/')[-1]
                $roleDisplayName = $role.roleDisplayName
                Write-Information "    $($roleDisplayName) - $($roleDefinitionName), Scope=$($scope)"

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
