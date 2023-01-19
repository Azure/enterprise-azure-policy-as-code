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

function New-AssignmentHelper {
    [CmdletBinding()]
    param (
        [PSCustomObject] $assignmentDefinition,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $allPolicySetDefinitions
    )

    $splatTransform = "name/Name description/Description displayName/DisplayName metadata/Metadata enforcementMode/EnforcementMode scope/Scope notScope/NotScope parameters/PolicyParameterObject:hashtable managedIdentityLocation/Location"
    [hashtable] $splat = $assignmentDefinition | Get-FilteredHashTable -splatTransform $splatTransform
    if ($assignmentDefinition.isPolicySet) {
        $policySetId = $assignmentDefinition.policySetId
        if ($allPolicySetDefinitions.ContainsKey($policySetId)) {
            $null = $splat.Add("PolicySetDefinition", $allPolicySetDefinitions[$policySetId])
        }
        else {
            throw "Invalid Policy Set Id $policySetId"
        }
    }
    else {
        $policyId = $assignmentDefinition.policyId
        if ($allPolicyDefinitions.ContainsKey($policyId)) {
            $null = $splat.Add("PolicyDefinition", $allPolicyDefinitions[$policyId])
        }
        else {
            throw "Invalid Policy Id $policyId"
        }
    }
    $null = $splat.Add("WarningAction", "SilentlyContinue")

    # Write-Information "'$($assignmentDefinition.displayName)', identityRequired=$($assignmentDefinition.identityRequired)"
    if ($assignmentDefinition.identityRequired) {
        $null = New-AzPolicyAssignment @splat -AssignIdentity
    }
    else {
        $null = New-AzPolicyAssignment @splat
    }
}

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-DeepClone.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $pacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -inputFolder $inputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive

$planFile = $pacEnvironment.policyPlanInputFile
$plan = Get-DeploymentPlan -planFile $planFile
if ($null -eq $plan) {
    Write-Warning "***************************************************************************************************"
    Write-Warning "Plan does not exist, skip Policy deployment."
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
            $null = Remove-AzPolicyExemption -Id $id -Force
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
        Write-Information "Delete removed Policy Set (Initiative) definitions ($($policySetDefinitions.Count))"
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
        Write-Information "Delete replaced Policy Set (Initiative) definitions ($($policySetDefinitions.Count))"
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
        Write-Information "Delete replaced Policy definitions ($($policyDefinitions.Count))"
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
        Write-Information "Create new Policy definitions ($($policyDefinitions.Count))"
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
        Write-Information "Recreate replaced Policy definitions ($($policyDefinitions.Count))"
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
        Write-Information "Update Policy definitions ($($policyDefinitions.Count))"
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
        Write-Information "Create new Policy Set (Initiative) definitions ($($policySetDefinitions.Count))"
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
        Write-Information "Recreate replaced Policy Set (Initiative) definitions ($($policySetDefinitions.Count))"
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
        Write-Information "Update Policy Set (Initiative) definitions ($($policySetDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinitionObj = $policySetDefinitions[$id]
            $splatTransform = $policySetDefinitionObj.splatTransform
            $policySetDefinition = $policySetDefinitionObj | Get-FilteredHashTable -splatTransform $splatTransform
            Write-Information $policySetDefinitionObj.displayName
            $null = Set-AzPolicySetDefinition @policySetDefinition
        }
    }

    # Policy Sets are updated, can now delete the obsolete Policy definitions
    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.delete
    if ($policyDefinitions.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete Policy definitions ($($policyDefinitions.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"

        foreach ($policyDefinitionName in $policyDefinitions.Keys) {
            $policyDefinition = $policyDefinitions[$policyDefinitionName]
            Write-Information $policyDefinition.displayName
            $null = Remove-AzPolicyDefinition -Id $policyDefinition.id -Force
        }
    }



    #endregion

    #region create and update assignments

    $count = $newAssignments.Count + $replaceAssignments.Count + $updateAssignments.Count
    if ($count -gt 0) {

        $deploymentRootScope = $pacEnvironment.deploymentRootScope
        $splatTransform = "scopeId:policyScope"
        $getPolicyScopeSplat = @{
            scopeId = $deploymentRootScope
        }
        $splat = $getPolicyScopeSplat | Get-FilteredHashTable -splatTransform $splatTransform
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Fetching existing Policy and Policy Set (Initiative) Definitions from scope '$deploymentRootScope'"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $policyDefinitionsList = Get-AzPolicyDefinition @splat
        $allPolicyDefinitions = @{}
        Write-Information "Policy definitions     = $($policyDefinitionsList.Count)"
        foreach ($policyDefinition in $policyDefinitionsList) {
            $allPolicyDefinitions.Add($policyDefinition.ResourceId, $policyDefinition)
        }
        $policySetDefinitionsList = Get-AzPolicySetDefinition @splat -ApiVersion "2020-08-01"
        $allPolicySetDefinitions = @{}
        Write-Information "Policy Set definitions = $($policySetDefinitionsList.Count)"
        foreach ($policySetDefinition in $policySetDefinitionsList) {
            $allPolicySetDefinitions.Add($policySetDefinition.ResourceId, $policySetDefinition)
        }

        if ($newAssignments.Count -gt 0) {
            Write-Information ""
            Write-Information "==================================================================================================="
            Write-Information "Create new Assignments ($($newAssignments.Count))"
            Write-Information "---------------------------------------------------------------------------------------------------"
            $currentDisplayName = "-"
            $newAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
                $displayName = $_.displayName
                if ($displayName -ne $currentDisplayName) {
                    Write-Information $displayName
                    $currentDisplayName = $displayName
                }
                Write-Information "    $($_.scope)"
                New-AssignmentHelper `
                    -assignmentDefinition $_ `
                    -allPolicyDefinitions $allPolicyDefinitions `
                    -allPolicySetDefinitions $allPolicySetDefinitions
            }
        }

        if ($replaceAssignments.Count -gt 0) {
            Write-Information ""
            Write-Information "==================================================================================================="
            Write-Information "Recreate replaced Assignments ($($replaceAssignments.Count))"
            Write-Information "---------------------------------------------------------------------------------------------------"
            $currentDisplayName = "-"
            $replaceAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
                $displayName = $_.displayName
                if ($displayName -ne $currentDisplayName) {
                    Write-Information $displayName
                    $currentDisplayName = $displayName
                }
                Write-Information "    $($_.scope)"
                New-AssignmentHelper `
                    -assignmentDefinition $_ `
                    -allPolicyDefinitions $allPolicyDefinitions `
                    -allPolicySetDefinitions $allPolicySetDefinitions
            }
        }

        if ($updateAssignments.Count -gt 0) {
            Write-Information ""
            Write-Information "==================================================================================================="
            Write-Information "Update Assignments ($($updateAssignments.Count))"
            Write-Information "---------------------------------------------------------------------------------------------------"
            $currentDisplayName = "-"
            $updateAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
                $splatTransform = $_.splatTransform
                $assignment = $_ | Get-FilteredHashTable -splatTransform $splatTransform
                $null = $assignment.Add("WarningAction", "SilentlyContinue")

                $displayName = $_.displayName
                if ($displayName -ne $currentDisplayName) {
                    Write-Information $displayName
                    $currentDisplayName = $displayName
                }
                Write-Information "    $($_.scope)"
                $null = Set-AzPolicyAssignment @assignment
            }
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
                $assignment = Get-Assignment -Id $policyAssignmentId
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
                $assignment = Get-Assignment -Id $policyAssignmentId
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
