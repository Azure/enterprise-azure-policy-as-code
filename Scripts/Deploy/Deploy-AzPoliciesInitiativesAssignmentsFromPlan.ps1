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

    [Parameter(Mandatory = $false, HelpMessage = "Output folder path for plan files. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Plan input filename. Defaults to `$InputFolder/policy-plan-`$PacEnvironmentSelector/policy-plan.json`"'.")]
    [string] $PlanFile,

    [Parameter(Mandatory = $false, HelpMessage = "Role Assignment plan output filename. Defaults to environment variable `$OutputFolder/roles-plan-`$PacEnvironmentSelector/roles-plan.json.")]
    [string] $RolesPlanFile,

    [Parameter(Mandatory = $false, HelpMessage = "Use switch to indicate interactive use")] [switch] $interactive
)

#region Az Helper Functions

function New-AzPolicyAssignmentHelper {
    [CmdletBinding()]
    param (
        [string] $assignmentId,
        [PSCustomObject] $assignmentDefinition,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $allInitiativeDefinitions,
        [hashtable] $addedRoleAssignments
    )

    $splatTransform = "Name Description DisplayName Metadata EnforcementMode Scope"
    [hashtable] $splat = $assignmentDefinition | Get-FilteredHashTable -splatTransform $splatTransform
    $splat.Add("PolicyParameterObject", ($assignmentDefinition.PolicyParameterObject | ConvertTo-HashTable))
    $notScope = $assignmentDefinition.NotScope
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

    Write-Information "`$assignmentDefinition: Name=$($assignmentDefinition.Name), identityRequired=$($assignmentDefinition.identityRequired)"
    Write-Information "`$assignmentDefinition: $($assignmentDefinition | ConvertTo-Json -Depth 100)"
    if ($assignmentDefinition.identityRequired) {
        $splat.Add("Location", $assignmentDefinition.managedIdentityLocation)
        $assignmentCreated = New-AzPolicyAssignment @splat -AssignIdentity
        $id = $assignmentDefinition.Id
        if ($addedRoleAssignments.ContainsKey($id)) {
            $value = $addedRoleAssignments.$id
            $value.identity = $assignmentCreated.Identity
        }
    }
    else {
        $null = New-AzPolicyAssignment @splat
    }
}

function Set-AzPolicyAssignmentHelper {
    [CmdletBinding()]
    param (
        [string] $assignmentId,
        $assignmentDefinition
    )

    $splatTransform = "Id Description DisplayName EnforcementMode Metadata"
    [hashtable] $splat = $assignmentDefinition | Get-FilteredHashTable -splatTransform $splatTransform
    $parameterObject = $assignmentDefinition.PolicyParameterObject | ConvertTo-HashTable
    $splat.Add("PolicyParameterObject", $parameterObject)
    $splat.Add("WarningAction", "SilentlyContinue")
    $notScope = $assignmentDefinition.NotScope
    if ($null -ne $notScope) {
        $splat.Add("NotScope", $notScope)
    }
    # else {
    #     $splat.Add("NotScope", @())
    # }

    $null = Set-AzPolicyAssignment @splat
}

#endregion

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-DeepClone.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

#region Deploy Plan

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive.IsPresent
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive -useAzPowerShell
if ($PlanFile -eq "") {
    $PlanFile = $pacEnvironment.policyPlanInputFile
}
if ($RolesPlanFile -eq "") {
    $RolesPlanFile = $pacEnvironment.rolesPlanOutputFile
}
$plan = Get-DeploymentPlan -PlanFile $PlanFile

Write-Information "==================================================================================================="
Write-Information "Execute (Deploy) plan from ""$PlanFile"""
Write-Information "==================================================================================================="
Write-Information "Plan created on               : $($plan.createdOn)"
Write-Information "Settings"
Write-Information "    rootScopeId               : $($plan.rootScopeId)"
Write-Information "    rootScope                 : $($plan.rootScope | ConvertTo-Json -Depth 100 -Compress)"
Write-Information "    TenantID                  : $($plan.TenantID)"
Write-Information "---------------------------------------------------------------------------------------------------"

[hashtable] $rolesPlan = @{
    changes = $false
    removed = @{}
    added   = @{}
}
$noChanges = $plan.noChanges

#endregion

if (!$noChanges) {
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
        $policyDefinition = $policyDefinitions[$policyDefinitionName] | Get-FilteredHashTable -splatTransform $splatTransform
        Write-Information "    ""$($policyDefinition.Name)"" - ""$($policyDefinition.DisplayName)"""
        $null = New-AzPolicyDefinition @policyDefinition
    }
    $policyDefinitions = $plan.updatedPolicyDefinitions | ConvertTo-HashTable
    Write-Information "Update Policy definitions ($($policyDefinitions.Count))"
    foreach ($policyDefinitionName in $policyDefinitions.Keys) {
        $policyDefinition = $policyDefinitions[$policyDefinitionName] | Get-FilteredHashTable -splatTransform $splatTransform
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
        $initiativeDefinition = $initiativeDefinitions[$initiativeDefinitionName] | Get-FilteredHashTable -splatTransform $splatTransform
        $initiativeDefinition.Add("ApiVersion", "2020-08-01")
        Write-Information "      ""$($initiativeDefinition.Name)"" - ""$($initiativeDefinition.DisplayName)"""
        $null = New-AzPolicySetDefinition @initiativeDefinition
    }
    $initiativeDefinitions = $plan.updatedInitiativeDefinitions | ConvertTo-HashTable
    Write-Information "Updated Initiative definitions ($($initiativeDefinitions.Count))"
    foreach ($initiativeDefinitionName in $initiativeDefinitions.Keys) {
        $initiativeDefinition = $initiativeDefinitions[$initiativeDefinitionName] | Get-FilteredHashTable -splatTransform $splatTransform
        $initiativeDefinition.Add("ApiVersion", "2020-08-01")
        Write-Information "      ""$($initiativeDefinition.Name)"" - ""$($initiativeDefinition.DisplayName)"""
        $null = Set-AzPolicySetDefinition @initiativeDefinition
    }
    #endregion

    #region Assignments
    [hashtable] $assignmentsToCreate = (ConvertTo-HashTable $plan.newAssignments) + (ConvertTo-HashTable $plan.replacedAssignments)
    [hashtable] $assignmentsToUpdate = $plan.updatedAssignments | ConvertTo-HashTable
    [hashtable] $addedRoleAssignments = $plan.addedRoleAssignments | ConvertTo-HashTable
    $count = $assignmentsToCreate.Count + $assignmentsToUpdate.Count
    if ($count -gt 0) {
        $rootScope = ConvertTo-HashTable $plan.rootScope
        $rootScopeId = $plan.rootScopeId
        Write-Information "---------------------------------------------------------------------------------------------------"
        Write-Information "Fetching existing Policy definitions from scope '$rootScopeId'"
        $oldDebug = $DebugPreference
        $DebugPreference = "SilentlyContinue"
        $existingCustomPolicyDefinitionsList = @() + (Get-AzPolicyDefinition @rootScope -Custom -WarningAction SilentlyContinue | Where-Object { $_.ResourceId -like "$rootScopeId/providers/Microsoft.Authorization/policyDefinitions/*" })
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

        Write-Information "Fetching existing Initiative definitions from scope ""$rootScopeId"""
        $oldDebug = $DebugPreference
        $DebugPreference = "SilentlyContinue"
        $existingCustomInitiativeDefinitionsList = Get-AzPolicySetDefinition @rootScope -ApiVersion "2020-08-01" -Custom -WarningAction SilentlyContinue | Where-Object { $_.ResourceId -like "$rootScopeId/providers/Microsoft.Authorization/policySetDefinitions/*" }
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
        foreach ($assignmentId in $assignmentsToCreate.Keys) {
            $assignment = $assignmentsToCreate[$assignmentId]
            Write-Information "    ""$($assignmentId)"""
            New-AzPolicyAssignmentHelper `
                -assignmentId $assignmentId `
                -assignmentDefinition $assignment `
                -allPolicyDefinitions $allPolicyDefinitions `
                -allInitiativeDefinitions $allInitiativeDefinitions `
                -addedRoleAssignments $addedRoleAssignments
        }
        Write-Information "Updated Assignments ($($assignmentsToUpdate.Count))"
        foreach ($assignmentId in $assignmentsToUpdate.Keys) {
            $assignment = $assignmentsToUpdate[$assignmentId]
            Write-Information "    ""$($assignmentId)"""
            Set-AzPolicyAssignmentHelper `
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

    #region Exemptions

    Write-Information "---------------------------------------------------------------------------------------------------"
    $exemptions = (ConvertTo-HashTable $plan.deletedExemptions) + (ConvertTo-HashTable $plan.replacedExemptions)
    Write-Information "Delete obsolete and replaced Exemptions ($($exemptions.Count))"
    foreach ($exemptionId in $exemptions.Keys) {
        $exemption = $exemptions[$exemptionId]
        Write-Information "    ""$($exemptionId)"" - ""$($exemption.DisplayName)"""
        Remove-AzPolicyExemption -Id $exemptionId -Force
    }

    Write-Information "---------------------------------------------------------------------------------------------------"
    $exemptions = (ConvertTo-HashTable $plan.newExemptions) + (ConvertTo-HashTable $plan.replacedExemptions)
    Write-Information "Create new and replaced Exemptions ($($exemptions.Count))"
    $splatTransform = "Name Scope DisplayName Description Metadata ExemptionCategory ExpiresOn PolicyDefinitionReferenceIds/PolicyDefinitionReferenceId"
    $assignmentsCache = @{}
    foreach ($exemptionId in $exemptions.Keys) {
        $exemption = $exemptions[$exemptionId]
        $policyAssignmentId = $exemption.policyAssignmentId
        $filteredExemption = $exemptions[$exemptionId] | Get-FilteredHashTable -splatTransform $splatTransform
        Write-Information "    ""$($exemptionId)"" - ""$($exemption.DisplayName)"""
        # Need assignment
        $assignment = $null
        if ($assignmentsCache.ContainsKey($policyAssignmentId)) {
            $assignment = $assignmentsCache.$policyAssignmentId
        }
        else {
            # Retrieve Policy Assignment
            $assignment = Get-AzPolicyAssignment -Id $policyAssignmentId
            $null = $assignmentsCache.Add($policyAssignmentId, $assignment)
        }
        $null = New-AzPolicyExemption @filteredExemption -PolicyAssignment $assignment
    }

    Write-Information "---------------------------------------------------------------------------------------------------"
    $exemptions = (ConvertTo-HashTable $plan.updatedExemptions)
    Write-Information "Update Exemptions ($($exemptions.Count))"
    $splatTransform = "Id DisplayName Description Metadata ExemptionCategory ExpiresOn ClearExpiration PolicyDefinitionReferenceIds/PolicyDefinitionReferenceId"
    foreach ($exemptionId in $exemptions.Keys) {
        $exemption = $exemptions[$exemptionId]
        $filteredExemption = $exemptions[$exemptionId] | Get-FilteredHashTable -splatTransform $splatTransform
        Write-Information "    ""$($exemptionId)"""
        $null = Set-AzPolicyExemption @filteredExemption
    }

    #endregion

    #region Role Assignment Plan

    Write-Information "==================================================================================================="
    Write-Information "Plan Role Assignments and save to  ""$RolesPlanFile"""
    Write-Information "---------------------------------------------------------------------------------------------------"

    [hashtable] $removedRoleAssignments = $plan.removedRoleAssignments | ConvertTo-HashTable
    if ($removedRoleAssignments.Count -gt 0) {
        Write-Information ""
        Write-Information "Removing Role Assignmnets for $($removedRoleAssignments.Count) Policy Assignments"
        foreach ($assignmentId in $removedRoleAssignments.Keys) {
            $removedRoleAssignment = $removedRoleAssignments.$assignmentId
            $identity = $removedRoleAssignment.identity
            $roleAssignments = $removedRoleAssignment.roleAssignments

            Write-Information "    Assignment `'$($removedRoleAssignment.DisplayName)`' ($($assignmentId))"
            Write-Information "            PrincipaId: $($identity.principalId)"

            foreach ($roleAssignment in $roleAssignments) {
                Write-Information "        '$($roleAssignment.roleDisplayName)' - '$($roleAssignment.roleDefinitionId)', Scope='$($roleAssignment.scope)'"
            }

        }
        Write-Information ""
    }
    if ($addedRoleAssignments.Count -gt 0) {
        Write-Information ""
        Write-Information "Adding Role Assignmnets for $($addedRoleAssignments.Count) Policy Assignments"
        foreach ($assignmentId in $addedRoleAssignments.Keys) {
            $addedRoleAssignment = $addedRoleAssignments.$assignmentId
            $identity = $addedRoleAssignment.identity
            $roles = $addedRoleAssignment.roles

            Write-Information "    Assignment `'$($addedRoleAssignment.DisplayName)`' ($($assignmentId))"
            Write-Information "            PrincipaId: $($identity.principalId)"

            foreach ($role in $roles) {
                Write-Information "        $($role.roleDisplayName) - $($role.roleDefinitionId), Scope=`'$($role.scope)`'"
            }

        }
        Write-Information ""
    }
    $rolesPlan = @{
        changes = $true
        removed = $removedRoleAssignments
        added   = $addedRoleAssignments
    }

    #endregion

}

$numberOfRoleChanges = ($rolesPlan.added).Count + ($rolesPlan.removed).Count
Write-Information "==================================================================================================="
Write-Information "Writing $($numberOfRoleChanges) Role Assignment changes to plan file $RolesPlanFile"
Write-Information "==================================================================================================="
if (-not (Test-Path $RolesPlanFile)) {
    $null = New-Item $RolesPlanFile -Force
}
$null = $rolesPlan | ConvertTo-Json -Depth 100 | Out-File -FilePath $RolesPlanFile -Force
#endregion
#endregion
