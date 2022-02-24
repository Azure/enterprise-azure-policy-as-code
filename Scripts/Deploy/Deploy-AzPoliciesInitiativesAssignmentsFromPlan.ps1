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

#region Az Helper Functions

function Build-AdditionalRoleDefinition {
    [CmdletBinding()]
    param (
        $assignmentCreated,
        $assignmentDefinition
    )
    $additionalRoleDefinition = @{
        $assignmentId = @{
            DisplayName = $assignmentDefinition.DisplayName
            identity    = $assignmentCreated.Identity
            roles       = $assignmentDefinition.Metadata.roles
        }
    }
    return $additionalRoleDefinition
}

function New-AzPolicyAssignmentHelper {
    [CmdletBinding()]
    param (
        [string] $assignmentId,
        [PSCustomObject] $assignmentDefinition,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $allInitiativeDefinitions
    )

    $splatTransform = "Name Description DisplayName Metadata EnforcementMode Scope"
    [hashtable] $splat = $assignmentDefinition | Get-FilteredHashTable -Filter $splatTransform
    $notScope = $assignmentDefinition.NotScope
    $splat.Add("PolicyParameterObject", ($assignmentDefinition.PolicyParameterObject | ConvertTo-HashTable))
    if ($null -ne $notScope -and $notScope.Length -gt 0) {
        $splat.Add("NotScope", $notScope)
    }
    if ($assignmentDefinition.initiativeId) {
        $initiativeId = $assignmentDefinition.initiativeId
        if ($allInitiativeDefinitions.ContainsKey($initiativeId)) {
            $splat.Add("PolicySetDefinition", $allInitiativeDefinitions[$initiativeId])
        }
        else {
            throw "Invalid Initiative Id $initiativeId"
        }
    }
    elseif ($assignmentDefinition.policyId) {
        $policyId = $assignmentDefinition.policyId
        if ($allPolicyDefinitions.ContainsKey($policyId)) {
            $splat.Add("PolicyDefinition", $allPolicyDefinitions[$policyId])
        }
        else {
            throw "Invalid Policy Id $policyId"
        }
    }
    else {
        throw "Assignments must specify a Policy Id or an Initiative Id"
    }
    $splat.Add("WarningAction", "SilentlyContinue")

    $additionalRoleDefinition = @{}
    if ($assignmentDefinition.identityRequired) {
        $splat.Add("Location", $assignmentDefinition.managedIdentityLocation)
        $assignmentCreated = New-AzPolicyAssignment @splat -AssignIdentity
        $additionalRoleDefinition = Build-AdditionalRoleDefinition -assignmentCreated $assignmentCreated -assignmentDefinition $assignmentDefinition
    }
    else {
        $null = New-AzPolicyAssignment @splat
    }
    return $additionalRoleDefinition
}

function Set-AzPolicyAssignmentHelper {
    [CmdletBinding()]
    param (
        [string] $assignmentId,
        $assignmentDefinition
    )

    $splatTransform = "Id Description DisplayName EnforcementMode Metadata"
    [hashtable] $splat = $assignmentDefinition | Get-FilteredHashTable -Filter $splatTransform
    $parmeterObject = $assignmentDefinition.PolicyParameterObject | ConvertTo-HashTable
    $splat.Add("PolicyParameterObject", $parmeterObject) 
    $notScope = $assignmentDefinition.NotScope
    if ($null -ne $notScope -and $notScope.Length -gt 0) {
        $splat.Add("NotScope", $notScope)
    }
    $splat.Add("WarningAction", "SilentlyContinue")

    $additionalRoleDefinition = @{}
    if ($assignmentDefinition.identityRequired -and $assignmentDefinition.addingIdentity) {
        $splat.Add("Location", $assignmentDefinition.managedIdentityLocation)
        $assignmentCreated = Set-AzPolicyAssignment @splat -AssignIdentity
        $additionalRoleDefinition = Build-AdditionalRoleDefinition -assignmentCreated $assignmentCreated -assignmentDefinition $assignmentDefinition
    }
    else {
        $null = Set-AzPolicyAssignment @splat
    }
    return $additionalRoleDefinition
}

#endregion

. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Utils/Get-DeepClone.ps1"
. "$PSScriptRoot/../Utils/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"

#region Deploy Plan

$additionalRoleDefinitions = @{}
$plan = Get-DeploymentPlan -PlanFile $PlanFile

Write-Information "==================================================================================================="
Write-Information "Execute (Deploy) plan from ""$PlanFile"""
Write-Information "==================================================================================================="
Write-Information "Plan created on               : $($plan.createdOn)"
Write-Information "Settings"
Write-Information "    rootScope                 : $($plan.RootScope)"
Write-Information "    scopeParam                : $($plan.scopeParam | ConvertTo-Json -Depth 100 -Compress)"
Write-Information "    TenantID                  : $($plan.TenantID)"
Write-Information "---------------------------------------------------------------------------------------------------"

$noChanges = $plan.noChanges
if ($noChanges) {
    Write-Information "********************** NO CHANGES NEEDED **********************************************************"
}
else {

    #region Delete Assignment, Initiatives and replaced Policies
    Write-Information "---------------------------------------------------------------------------------------------------"
    $assignments = (ConvertTo-HashTable $plan.deletedAssignments) + (ConvertTo-HashTable $plan.replacedAssignments)
    Write-Information "Delete obsolete and replaced Assignments ($($assignments.Count))"
    foreach ($assignmentId in $assignments.Keys) {
        $assignment = $assignments[$assignmentId]
        Write-Information "    ""$($assignmentId)"" - ""$($assignment.DisplayName)"""
        Remove-AzPolicyAssignment -Id $assignmentId
    }
    $initiativeDefinitions = (ConvertTo-HashTable $plan.deletedInitiativeDefinitions) + (ConvertTo-HashTable $plan.replacedInitiativeDefinitions)
    Write-Information "Delete obsolete and replaced Initiative definitions ($($initiativeDefinitions.Count))"
    foreach ($initiativeDefinitionName in $initiativeDefinitions.Keys) {
        $initiativeDefinition = $initiativeDefinitions[$initiativeDefinitionName]
        Write-Information "      $initiativeDefinitionName - $($initiativeDefinition.id)"
        Remove-AzPolicySetDefinition -Id $initiativeDefinition.id -Force
    }
    $policyDefinitions = $plan.replacedPolicyDefinitions | ConvertTo-HashTable
    Write-Information "Delete replaced Policy definitions ($($policyDefinitions.Count))"
    foreach ($policyDefinitionName in $policyDefinitions.Keys) {
        $policyDefinition = $policyDefinitions[$policyDefinitionName]
        Write-Information "    ""$($policyDefinition.Name)"" - ""$($policyDefinition.DisplayName)"""
        Remove-AzPolicyDefinition -Id $policyDefinition.id -Force
    }
    #endregion

    #region Policy definitions
    Write-Information "---------------------------------------------------------------------------------------------------"
    $policyDefinitions = (ConvertTo-HashTable $plan.newPolicyDefinitions) + (ConvertTo-HashTable $plan.replacedPolicyDefinitions)
    Write-Information "Create new and replaced (create) Policy definitions ($($policyDefinitions.Count))"
    $splatTransform = "Name DisplayName Description Metadata Mode Parameter Policy ManagementGroupName SubscriptionId"
    foreach ($policyDefinitionName in $policyDefinitions.Keys) {
        $policyDefinition = $policyDefinitions[$policyDefinitionName] | Get-FilteredHashTable -Filter $splatTransform
        Write-Information "    ""$($policyDefinition.Name)"" - ""$($policyDefinition.DisplayName)"""
        $null = New-AzPolicyDefinition @policyDefinition
    }
    $policyDefinitions = $plan.updatedPolicyDefinitions | ConvertTo-HashTable
    Write-Information "Update Policy definitions ($($policyDefinitions.Count))"
    foreach ($policyDefinitionName in $policyDefinitions.Keys) {
        $policyDefinition = $policyDefinitions[$policyDefinitionName] | Get-FilteredHashTable -Filter $splatTransform
        Write-Information "    ""$($policyDefinition.Name)"" - ""$($policyDefinition.DisplayName)"""
        $null = Set-AzPolicyDefinition @policyDefinition
    }
    #endregion

    #region Initiative definitions
    Write-Information "---------------------------------------------------------------------------------------------------"
    $initiativeDefinitions = (ConvertTo-HashTable $plan.newInitiativeDefinitions) + (ConvertTo-HashTable $plan.replacedInitiativeDefinitions)
    Write-Information "Create new and replaced Initiative definitions ($($initiativeDefinitions.Count))"
    $splatTransform = "Name DisplayName Description Metadata Parameter PolicyDefinition GroupDefinition ManagementGroupName SubscriptionId"
    foreach ($initiativeDefinitionName in $initiativeDefinitions.Keys) {
        $initiativeDefinition = $initiativeDefinitions[$initiativeDefinitionName] | Get-FilteredHashTable -Filter $splatTransform
        $initiativeDefinition.Add("ApiVersion", "2020-08-01")
        Write-Information "      ""$($initiativeDefinition.Name)"" - ""$($initiativeDefinition.DisplayName)"""
        $null = New-AzPolicySetDefinition @initiativeDefinition
    }
    $initiativeDefinitions = $plan.updatedInitiativeDefinitions | ConvertTo-HashTable
    Write-Information "Updated Initiative definitions ($($initiativeDefinitions.Count))"
    foreach ($initiativeDefinitionName in $initiativeDefinitions.Keys) {
        $initiativeDefinition = $initiativeDefinitions[$initiativeDefinitionName] | Get-FilteredHashTable -Filter $splatTransform
        $initiativeDefinition.Add("ApiVersion", "2020-08-01")
        Write-Information "      ""$($initiativeDefinition.Name)"" - ""$($initiativeDefinition.DisplayName)"""
        $null = Set-AzPolicySetDefinition @initiativeDefinition
    }
    #endregion

    #region Assignments
    $assignmentsToCreate = (ConvertTo-HashTable $plan.newAssignments) + (ConvertTo-HashTable $plan.replacedAssignments)
    $assignmentsToUpdate = $plan.updatedAssignments | ConvertTo-HashTable
    $count = $assignmentsToCreate.Count + $assignmentsToUpdate.Count
    if ($count -gt 0) {
        $RootScope = $plan.rootScope
        Write-Information "---------------------------------------------------------------------------------------------------"
        Write-Information "Fetching existing Policy definitions from scope ""$RootScope"""
        $oldDebug = $DebugPreference
        $DebugPreference = "SilentlyContinue"
        $scopeParam = $plan.scopeParam | ConvertTo-HashTable
        $existingCustomPolicyDefinitionsList = @() + (Get-AzPolicyDefinition @scopeParam -Custom -WarningAction SilentlyContinue | Where-Object { $_.ResourceId -like "$RootScope/providers/Microsoft.Authorization/policyDefinitions/*" })
        $builtInPolicyDefinitions = @() + (Get-AzPolicyDefinition -BuiltIn -WarningAction SilentlyContinue)
        $DebugPreference = $oldDebug
        $allPolicyDefinitions = @{}
        Write-Information "    Custom: $($existingCustomPolicyDefinitionsList.Length)"
        Write-Information "    Built-In: $($builtInPolicyDefinitions.Length)"
        foreach ($builtInPolicy in $builtInPolicyDefinitions) {
            $allPolicyDefinitions.Add($builtInPolicy.ResourceId, $builtInPolicy)
        }
        foreach ($existingCustomPolicyDefinition in $existingCustomPolicyDefinitionsList) {
            $allPolicyDefinitions.Add($existingCustomPolicyDefinition.ResourceId, $existingCustomPolicyDefinition)
        }

        Write-Information "Fetching existing Initiative definitions from scope ""$RootScope"""
        $oldDebug = $DebugPreference
        $DebugPreference = "SilentlyContinue"
        $existingCustomInitiativeDefinitionsList = Get-AzPolicySetDefinition @scopeParam -ApiVersion "2020-08-01" -Custom -WarningAction SilentlyContinue | Where-Object { $_.ResourceId -like "$RootScope/providers/Microsoft.Authorization/policySetDefinitions/*" }
        $builtInInitiativeDefinitions = Get-AzPolicySetDefinition -ApiVersion "2020-08-01" -BuiltIn -WarningAction SilentlyContinue
        $DebugPreference = $oldDebug

        $allInitiativeDefinitions = @{}
        Write-Information "    Built-In: $($builtInInitiativeDefinitions.Length)"
        Write-Information "    Custom: $($existingCustomInitiativeDefinitionsList.Length)"
        foreach ($builtInInitiative in $builtInInitiativeDefinitions) {
            $allInitiativeDefinitions.Add($builtInInitiative.ResourceId, $builtInInitiative)
        }

        foreach ($existingCustomInitiativeDefinition in $existingCustomInitiativeDefinitionsList) {
            $allInitiativeDefinitions.Add($existingCustomInitiativeDefinition.ResourceId, $existingCustomInitiativeDefinition)
        }

        Write-Information "Create new and replaced Assignments ($($assignmentsToCreate.Count))"
        $additionalRoleDefinitions = @{}
        foreach ($assignmentId in $assignmentsToCreate.Keys) {
            $assignment = $assignmentsToCreate[$assignmentId]
            Write-Information "    ""$($assignmentId)"""
            $additionalRoleDefinitions += New-AzPolicyAssignmentHelper `
                -assignmentId $assignmentId `
                -assignmentDefinition $assignment `
                -allPolicyDefinitions $allPolicyDefinitions `
                -allInitiativeDefinitions $allInitiativeDefinitions
        }
        Write-Information "Updated Assignments ($($assignmentsToUpdate.Count))"
        foreach ($assignmentId in $assignmentsToUpdate.Keys) {
            $assignment = $assignmentsToUpdate[$assignmentId]
            Write-Information "    ""$($assignmentId)"""
            $additionalRoleDefinitions += Set-AzPolicyAssignmentHelper `
                -assignmentId $assignmentId `
                -assignmentDefinition $assignment
        }
    }
    else {
        Write-Information "Create new and replaced Assignments (0)"
        Write-Information "Updated Assignments (0)"
    }

    #endregion

    #region Delete obsolete Policy definitions
    Write-Information "---------------------------------------------------------------------------------------------------"
    $policyDefinitions = $plan.deletedPolicyDefinitions | ConvertTo-HashTable
    Write-Information "Deleted Policy definitions ($($policyDefinitions.Count))"
    foreach ($policyDefinitionName in $policyDefinitions.Keys) {
        $policyDefinition = $policyDefinitions[$policyDefinitionName]
        Write-Information "    ""$($policyDefinition.name)"" - ""$($policyDefinition.displayName)"""
        $null = Remove-AzPolicyDefinition -Id $policyDefinition.id -Force
    }
    #endregion

    #region add Role Assignmnets
    $roleAssignments = ($plan.addedRoleAssignments | ConvertTo-HashTable) + $additionalRoleDefinitions
    Write-Information "Add new Role Assignments for $($roleAssignments.Count) Policy Assignments"
    $retriesLimit = 8
    foreach ($assignmentId in $roleAssignments.Keys) {
        $roleAssignment = $roleAssignments[$assignmentId]
        $identity = $roleAssignment.identity
        $roles = $roleAssignment.roles
        Write-Information "    ""$($assignmentId)"""
        Write-Information "        PrincipalId=$($identity.PrincipalId) with $($roles.length) Roles"
        foreach ($role in $roles) {
            $scope = $role.scope
            $roleDefinitionId = $role.roleDefinitionId
            Write-Information "        Scope=$scope, RoleDefinitionId=$roleDefinitionId"
            $needToRetry = $true
            $retries = 0
            while ($needToRetry) {
                try {
                    $null = New-AzRoleAssignment -Scope $scope -ObjectId $identity.PrincipalId -RoleDefinitionId $roleDefinitionId
                    $needToRetry = $false
                }
                catch {
                    If ($_.Exception.Body.Error.Message.Contains("role assignment already exists")) {
                        # Write-Host "##[warning] Role assignment already existed: New-AzRoleAssignment -Scope $($scope) -ObjectId $($identity.PrincipalId) -RoleDefinitionId $roleDefinitionId"
                        $needToRetry = $false
                    }
                    else {
                        # Write-Host "##[warning] Call failed - retrying in 10 seconds: New-AzRoleAssignment -Scope $($scope) -ObjectId $($identity.PrincipalId) -RoleDefinitionId $roleDefinitionId"
                        Start-Sleep -Seconds 10
                        $retries++
                        if ($retries -gt $retriesLimit) {
                            Write-Host "##[error] $($_): $($_.Exception)"
                            throw
                        }
                    }
                }
            }
        }
    }
    #endregion

    Write-Information "---------------------------------------------------------------------------------------------------"

}

Write-Information ""
Write-Information ""

#endregion
