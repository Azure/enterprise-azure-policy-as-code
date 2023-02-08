#Requires -PSEdition Core

<#
.SYNOPSIS
    This script deploys the component as defined in the plan JSON:

#>

[CmdletBinding()]
param (
    [parameter(
        HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.",
        Position = 0
    )]
    [string] $pacEnvironmentSelector,

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder,

    [Parameter(HelpMessage = "Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string] $inputFolder,

    [Parameter(HelpMessage = "Use switch to indicate interactive use")]
    [switch] $interactive
)

. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

. "$PSScriptRoot/../Helpers/Get-DeepClone.ps1"
. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"

. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"

. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"
. "$PSScriptRoot/../Helpers/Set-AzPolicyAssignmentRestMethod.ps1"
. "$PSScriptRoot/../Helpers/Split-ScopeId.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $pacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -inputFolder $inputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive

$planFile = $pacEnvironment.policyPlanInputFile
$plan = Get-DeploymentPlan -planFile $planFile
if ($null -eq $plan) {
    Write-Warning "***************************************************************************************************"
    Write-Warning "Plan does not exist, skipping Policy resource deployment."
    Write-Warning "***************************************************************************************************"
    Write-Warning ""
}
else {

    Write-Information "***************************************************************************************************"
    Write-Information "Deploy Policy resources from plan in file '$planFile'"
    Write-Information "Plan created on $($plan.createdOn)."
    Write-Information "***************************************************************************************************"

    [hashtable] $newAssignments = ConvertTo-HashTable $plan.assignments.new
    [hashtable] $replaceAssignments = ConvertTo-HashTable $plan.assignments.replace
    [hashtable] $updateAssignments = ConvertTo-HashTable $plan.assignments.update

    #region delete exemptions, assignment, definitions

    $exemptions = ConvertTo-HashTable $plan.exemptions.delete
    if ($exemptions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete orphaned, deleted, and expired Exemptions ($($exemptions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $exemptions.Keys) {
            $exemption = $exemptions[$id]
            Write-Information $exemption.displayName
            $null = Remove-AzPolicyExemption -Id $id -Force -ErrorAction Continue
        }
    }

    $exemptions = ConvertTo-HashTable $plan.exemptions.replace
    if ($exemptions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Exemptions ($($exemptions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $exemptions.Keys) {
            $exemption = $exemptions[$id]
            Write-Information $exemption.displayName
            $null = Remove-AzPolicyExemption -Id $id -Force
        }
    }

    $assignments = ConvertTo-HashTable $plan.assignments.delete
    if ($assignments.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed Assignments ($($assignments.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $assignments.Keys) {
            $assignment = $assignments[$id]
            Write-Information $assignment.displayName
            $null = Remove-AzPolicyAssignment -Id $id
        }
    }

    $assignments = $replaceAssignments
    if ($assignments.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Assignments ($($assignments.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $assignments.Keys) {
            $assignment = $assignments[$id]
            Write-Information $assignment.displayName
            $null = Remove-AzPolicyAssignment -Id $id
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.delete
    if ($policySetDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed Policy Sets ($($policySetDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinition = $policySetDefinitions[$id]
            Write-Information $policySetDefinition.displayName
            $null = Remove-AzPolicySetDefinition -Id $id -Force
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($policySetDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Policy Sets ($($policySetDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinition = $policySetDefinitions[$id]
            Write-Information $policySetDefinition.displayName
            $null = Remove-AzPolicySetDefinition -Id $id -Force
        }
    }

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($policyDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Policies ($($policyDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $policyDefinition = $policyDefinitions[$id]
            Write-Information $policyDefinition.displayName
            $null = Remove-AzPolicyDefinition -Id $id -Force
        }
    }

    #endregion

    #region create and update definitions

    $splatTransform = "name/Name displayName/DisplayName scopeId:policyScope description/Description metadata/Metadata mode/Mode parameters/Parameter policyRule/Policy"

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.new
    if ($policyDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Policies ($($policyDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $policyDefinitionObj = $policyDefinitions[$id]
            $policyDefinition = $policyDefinitionObj | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $policyDefinitionObj.displayName
            $null = New-AzPolicyDefinition @policyDefinition
        }
    }

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($policyDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Policies ($($policyDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $policyDefinitionObj = $policyDefinitions[$id]
            $policyDefinition = $policyDefinitionObj | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $policyDefinitionObj.displayName
            $null = New-AzPolicyDefinition @policyDefinition
        }
    }

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.update
    if ($policyDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Policies ($($policyDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $policyDefinitionObj = $policyDefinitions[$id]
            Write-Information $policyDefinitionObj.displayName
            $splatTransform = $policyDefinitionObj.splatTransform
            $policyDefinition = $policyDefinitionObj | Get-FilteredHashTable -splatTransform $splatTransform
            $null = Set-AzPolicyDefinition @policyDefinition
        }
    }

    $splatTransform = "name/Name displayName/DisplayName scopeId:policyScope description/Description metadata/Metadata parameters/Parameter policyDefinitions/PolicyDefinition policyDefinitionGroups/GroupDefinition"
    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.new
    if ($policySetDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Policy Sets ($($policySetDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinitionObj = $policySetDefinitions[$id]
            $policySetDefinition = $policySetDefinitionObj | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $policySetDefinitionObj.displayName
            $null = New-AzPolicySetDefinition @policySetDefinition
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($policySetDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Policy Sets  ($($policySetDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinitionObj = $policySetDefinitions[$id]
            $policySetDefinition = $policySetDefinitionObj | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $policySetDefinitionObj.displayName
            $null = New-AzPolicySetDefinition @policySetDefinition
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.update
    if ($policySetDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Policy Sets ($($policySetDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinitionObj = $policySetDefinitions[$id]
            $splatTransform = $policySetDefinitionObj.splatTransform
            $policySetDefinition = $policySetDefinitionObj | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $policySetDefinitionObj.displayName
            $null = Set-AzPolicySetDefinition @policySetDefinition
        }
    }

    # Policy Sets are updated, can now delete the obsolete Policies
    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.delete
    if ($policyDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete Policies ($($policyDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"

        foreach ($policyDefinitionName in $policyDefinitions.Keys) {
            $policyDefinition = $policyDefinitions[$policyDefinitionName]
            Write-Information $policyDefinition.displayName
            $null = Remove-AzPolicyDefinition -Id $policyDefinition.id -Force
        }
    }



    #endregion

    #region create and update assignments

    if ($newAssignments.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Assignments ($($newAssignments.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $newAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -assignment $_ -currentDisplayName $currentDisplayName
        }
    }

    if ($replaceAssignments.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Assignments ($($replaceAssignments.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $replaceAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -assignment $_ -currentDisplayName $currentDisplayName
        }
    }

    if ($updateAssignments.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Assignments ($($updateAssignments.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $updateAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -assignment $_ -currentDisplayName $currentDisplayName
        }
    }

    #endregion

    #region Exemptions

    $exemptions = ConvertTo-HashTable $plan.exemptions.new
    if ($exemptions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Exemptions ($($exemptions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $splatTransform = "name/Name scope/Scope displayName/DisplayName description/Description metadata/Metadata exemptionCategory/ExemptionCategory expiresOn/ExpiresOn policyDefinitionReferenceIds/PolicyDefinitionReferenceId"
        $assignmentsCache = @{}
        foreach ($exemptionId in $exemptions.Keys) {
            $exemption = $exemptions.$exemptionId
            $policyAssignmentId = $exemption.policyAssignmentId
            $filteredExemption = $exemption | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $exemption.displayName
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
    }

    $exemptions = ConvertTo-HashTable $plan.exemptions.replace
    if ($exemptions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create replaced Exemptions ($($exemptions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $splatTransform = "name/Name scope/Scope displayName/DisplayName description/Description metadata/Metadata exemptionCategory/ExemptionCategory expiresOn/ExpiresOn policyDefinitionReferenceIds/PolicyDefinitionReferenceId"
        $assignmentsCache = @{}
        foreach ($exemptionId in $exemptions.Keys) {
            $exemption = $exemptions.$exemptionId
            $policyAssignmentId = $exemption.policyAssignmentId
            $filteredExemption = $exemption | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $exemption.displayName
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
    }

    $exemptions = (ConvertTo-HashTable $plan.exemptions.update)
    if ($exemptions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Exemptions ($($exemptions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($exemptionId in $exemptions.Keys) {
            $exemption = $exemptions[$exemptionId]
            $splatTransform = $exemption.splatTransform
            $filteredExemption = $exemption | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $exemption.displayName
            $null = Set-AzPolicyExemption @filteredExemption
        }
    }

    #endregion

}
