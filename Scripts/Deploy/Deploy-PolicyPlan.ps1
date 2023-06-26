#Requires -PSEdition Core

<#
.SYNOPSIS
    Deploys Policy resources from a plan file.

.PARAMETER pacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER definitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER inputFolder
    Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.

.PARAMETER interactive
    Use switch to indicate interactive use

.EXAMPLE
    Deploy-PolicyPlan.ps1 -pacEnvironmentSelector "dev" -definitionsRootFolder "C:\git\policy-as-code\Definitions" -inputFolder "C:\git\policy-as-code\Output" -interactive
    Deploys Policy resources from a plan file.

.EXAMPLE
    Deploy-PolicyPlan.ps1 -pacEnvironmentSelector "dev" -interactive
    Deploys Policy resources from a plan file.  

.LINK
    https://azure.github.io/enterprise-azure-policy-as-code/#deployment-scripts

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

$PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
}

Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

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
    if ($exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete orphaned, deleted, and expired Exemptions ($($exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $exemptions.Keys) {
            $exemption = $exemptions[$id]
            Write-Information $exemption.displayName
            $null = Remove-AzPolicyExemption -Id $id -Force -ErrorAction Continue
        }
    }

    $exemptions = ConvertTo-HashTable $plan.exemptions.replace
    if ($exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Exemptions ($($exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $exemptions.Keys) {
            $exemption = $exemptions[$id]
            Write-Information $exemption.displayName
            $null = Remove-AzPolicyExemption -Id $id -Force
        }
    }

    $assignments = ConvertTo-HashTable $plan.assignments.delete
    if ($assignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed Assignments ($($assignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $assignments.Keys) {
            $assignment = $assignments[$id]
            Write-Information $assignment.displayName
            $null = Remove-AzPolicyAssignment -Id $id
        }
    }

    $assignments = $replaceAssignments
    if ($assignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Assignments ($($assignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $assignments.Keys) {
            $assignment = $assignments[$id]
            Write-Information $assignment.displayName
            $null = Remove-AzPolicyAssignment -Id $id
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.delete
    if ($policySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed Policy Sets ($($policySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinition = $policySetDefinitions[$id]
            Write-Information $policySetDefinition.displayName
            $null = Remove-AzPolicySetDefinition -Id $id -Force
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($policySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Policy Sets ($($policySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $policySetDefinition = $policySetDefinitions[$id]
            Write-Information $policySetDefinition.displayName
            $null = Remove-AzPolicySetDefinition -Id $id -Force
        }
    }

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($policyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Policies ($($policyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $policyDefinition = $policyDefinitions[$id]
            Write-Information $policyDefinition.displayName
            $null = Remove-AzPolicyDefinition -Id $id -Force
        }
    }

    #endregion

    #region create and update definitions

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.new
    if ($policyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Policies ($($policyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $definitionObj = $policyDefinitions[$id]
            $null = Set-AzPolicyDefinitionRestMethod -definition $definitionObj
        }
    }

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($policyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Policies ($($policyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $definitionObj = $policyDefinitions[$id]
            $null = Set-AzPolicyDefinitionRestMethod -definition $definitionObj
        }
    }

    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.update
    if ($policyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Policies ($($policyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policyDefinitions.Keys) {
            $definitionObj = $policyDefinitions[$id]
            $null = Set-AzPolicyDefinitionRestMethod -definition $definitionObj
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.new
    if ($policySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Policy Sets ($($policySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $definitionObj = $policySetDefinitions[$id]
            $null = Set-AzPolicySetDefinitionRestMethod -definition $definitionObj
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($policySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Policy Sets  ($($policySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $definitionObj = $policySetDefinitions[$id]
            $null = Set-AzPolicySetDefinitionRestMethod -definition $definitionObj
        }
    }

    $policySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.update
    if ($policySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Policy Sets ($($policySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($id in $policySetDefinitions.Keys) {
            $definitionObj = $policySetDefinitions[$id]
            $null = Set-AzPolicySetDefinitionRestMethod -definition $definitionObj
        }
    }

    # Policy Sets are updated, can now delete the obsolete Policies
    $policyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.delete
    if ($policyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete Policies ($($policyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"

        foreach ($policyDefinitionName in $policyDefinitions.Keys) {
            $policyDefinition = $policyDefinitions[$policyDefinitionName]
            Write-Information $policyDefinition.displayName
            $null = Remove-AzPolicyDefinition -Id $policyDefinition.id -Force
        }
    }



    #endregion

    #region create and update assignments

    if ($newAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Assignments ($($newAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $newAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -assignment $_ -currentDisplayName $currentDisplayName
        }
    }

    if ($replaceAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Assignments ($($replaceAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $replaceAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -assignment $_ -currentDisplayName $currentDisplayName
        }
    }

    if ($updateAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Assignments ($($updateAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $updateAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -assignment $_ -currentDisplayName $currentDisplayName
        }
    }

    #endregion

    #region Exemptions

    $exemptions = ConvertTo-HashTable $plan.exemptions.new
    if ($exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Exemptions ($($exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($exemptionId in $exemptions.Keys) {
            $exemption = $exemptions.$exemptionId
            $null = Set-AzPolicyExemptionRestMethod -exemptionObj $exemption
        }
    }

    $exemptions = ConvertTo-HashTable $plan.exemptions.replace
    if ($exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create replaced Exemptions ($($exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($exemptionId in $exemptions.Keys) {
            $exemption = $exemptions.$exemptionId
            $null = Set-AzPolicyExemptionRestMethod -exemptionObj $exemption
        }
    }

    $exemptions = (ConvertTo-HashTable $plan.exemptions.update)
    if ($exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Exemptions ($($exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($exemptionId in $exemptions.Keys) {
            $exemption = $exemptions.$exemptionId
            $null = Set-AzPolicyExemptionRestMethod -exemptionObj $exemption
        }
    }

    #endregion

}
