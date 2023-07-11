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
    Deploy-PolicyPlan.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -InputFolder "C:\git\policy-as-code\Output" -Interactive
    Deploys Policy resources from a plan file.

.EXAMPLE
    Deploy-PolicyPlan.ps1 -PacEnvironmentSelector "dev" -Interactive
    Deploys Policy resources from a plan file.  

.LINK
    https://azure.github.io/enterprise-azure-Policy-as-code/#deployment-scripts

#>

[CmdletBinding()]
param (
    [parameter(
        HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.",
        Position = 0
    )]
    [string] $PacEnvironmentSelector,

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(HelpMessage = "Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string] $InputFolder,

    [Parameter(HelpMessage = "Use switch to indicate interactive use")]
    [switch] $Interactive
)

$PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
}

Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$PacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -InputFolder $InputFolder -Interactive $Interactive
Set-AzCloudTenantSubscription -Cloud $PacEnvironment.cloud -TenantId $PacEnvironment.tenantId -Interactive $PacEnvironment.interactive

$PlanFile = $PacEnvironment.policyPlanInputFile
$plan = Get-DeploymentPlan -PlanFile $PlanFile
if ($null -eq $plan) {
    Write-Warning "***************************************************************************************************"
    Write-Warning "Plan does not exist, skipping Policy resource deployment."
    Write-Warning "***************************************************************************************************"
    Write-Warning ""
}
else {

    Write-Information "***************************************************************************************************"
    Write-Information "Deploy Policy resources from plan in file '$PlanFile'"
    Write-Information "Plan created on $($plan.createdOn)."
    Write-Information "***************************************************************************************************"

    [hashtable] $newAssignments = ConvertTo-HashTable $plan.assignments.new
    [hashtable] $replaceAssignments = ConvertTo-HashTable $plan.assignments.replace
    [hashtable] $updateAssignments = ConvertTo-HashTable $plan.assignments.update

    #region delete exemptions, assignment, definitions

    $Exemptions = ConvertTo-HashTable $plan.exemptions.delete
    if ($Exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete orphaned, deleted, and expired Exemptions ($($Exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $Exemptions.Keys) {
            $exemption = $Exemptions[$Id]
            Write-Information $exemption.displayName
            $null = Remove-AzPolicyExemption -Id $Id -Force -ErrorAction Continue
        }
    }

    $Exemptions = ConvertTo-HashTable $plan.exemptions.replace
    if ($Exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Exemptions ($($Exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $Exemptions.Keys) {
            $exemption = $Exemptions[$Id]
            Write-Information $exemption.displayName
            $null = Remove-AzPolicyExemption -Id $Id -Force
        }
    }

    $Assignments = ConvertTo-HashTable $plan.assignments.delete
    if ($Assignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed Assignments ($($Assignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $Assignments.Keys) {
            $Assignment = $Assignments[$Id]
            Write-Information $Assignment.displayName
            $null = Remove-AzPolicyAssignment -Id $Id
        }
    }

    $Assignments = $replaceAssignments
    if ($Assignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Assignments ($($Assignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $Assignments.Keys) {
            $Assignment = $Assignments[$Id]
            Write-Information $Assignment.displayName
            $null = Remove-AzPolicyAssignment -Id $Id
        }
    }

    $PolicySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.delete
    if ($PolicySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed Policy Sets ($($PolicySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicySetDefinitions.Keys) {
            $PolicySetDefinition = $PolicySetDefinitions[$Id]
            Write-Information $PolicySetDefinition.displayName
            $null = Remove-AzPolicySetDefinition -Id $Id -Force
        }
    }

    $PolicySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($PolicySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Policy Sets ($($PolicySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicySetDefinitions.Keys) {
            $PolicySetDefinition = $PolicySetDefinitions[$Id]
            Write-Information $PolicySetDefinition.displayName
            $null = Remove-AzPolicySetDefinition -Id $Id -Force
        }
    }

    $PolicyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($PolicyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Policies ($($PolicyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicyDefinitions.Keys) {
            $PolicyDefinition = $PolicyDefinitions[$Id]
            Write-Information $PolicyDefinition.displayName
            $null = Remove-AzPolicyDefinition -Id $Id -Force
        }
    }

    #endregion

    #region create and update definitions

    $PolicyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.new
    if ($PolicyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Policies ($($PolicyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicyDefinitions.Keys) {
            $DefinitionObj = $PolicyDefinitions[$Id]
            $null = Set-AzPolicyDefinitionRestMethod -Definition $DefinitionObj
        }
    }

    $PolicyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($PolicyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Policies ($($PolicyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicyDefinitions.Keys) {
            $DefinitionObj = $PolicyDefinitions[$Id]
            $null = Set-AzPolicyDefinitionRestMethod -Definition $DefinitionObj
        }
    }

    $PolicyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.update
    if ($PolicyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Policies ($($PolicyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicyDefinitions.Keys) {
            $DefinitionObj = $PolicyDefinitions[$Id]
            $null = Set-AzPolicyDefinitionRestMethod -Definition $DefinitionObj
        }
    }

    $PolicySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.new
    if ($PolicySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Policy Sets ($($PolicySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicySetDefinitions.Keys) {
            $DefinitionObj = $PolicySetDefinitions[$Id]
            $null = Set-AzPolicySetDefinitionRestMethod -Definition $DefinitionObj
        }
    }

    $PolicySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($PolicySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Policy Sets  ($($PolicySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicySetDefinitions.Keys) {
            $DefinitionObj = $PolicySetDefinitions[$Id]
            $null = Set-AzPolicySetDefinitionRestMethod -Definition $DefinitionObj
        }
    }

    $PolicySetDefinitions = ConvertTo-HashTable $plan.policySetDefinitions.update
    if ($PolicySetDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Policy Sets ($($PolicySetDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($Id in $PolicySetDefinitions.Keys) {
            $DefinitionObj = $PolicySetDefinitions[$Id]
            $null = Set-AzPolicySetDefinitionRestMethod -Definition $DefinitionObj
        }
    }

    # Policy Sets are updated, can now delete the obsolete Policies
    $PolicyDefinitions = ConvertTo-HashTable $plan.policyDefinitions.delete
    if ($PolicyDefinitions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete Policies ($($PolicyDefinitions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"

        foreach ($PolicyDefinitionName in $PolicyDefinitions.Keys) {
            $PolicyDefinition = $PolicyDefinitions[$PolicyDefinitionName]
            Write-Information $PolicyDefinition.displayName
            $null = Remove-AzPolicyDefinition -Id $PolicyDefinition.id -Force
        }
    }



    #endregion

    #region create and update assignments

    if ($newAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Assignments ($($newAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $CurrentDisplayName = "-"
        $newAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $CurrentDisplayName = Set-AzPolicyAssignmentRestMethod -Assignment $_ -CurrentDisplayName $CurrentDisplayName
        }
    }

    if ($replaceAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Assignments ($($replaceAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $CurrentDisplayName = "-"
        $replaceAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $CurrentDisplayName = Set-AzPolicyAssignmentRestMethod -Assignment $_ -CurrentDisplayName $CurrentDisplayName
        }
    }

    if ($updateAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Assignments ($($updateAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $CurrentDisplayName = "-"
        $updateAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $CurrentDisplayName = Set-AzPolicyAssignmentRestMethod -Assignment $_ -CurrentDisplayName $CurrentDisplayName
        }
    }

    #endregion

    #region Exemptions

    $Exemptions = ConvertTo-HashTable $plan.exemptions.new
    if ($Exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create new Exemptions ($($Exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($exemptionId in $Exemptions.Keys) {
            $exemption = $Exemptions.$exemptionId
            $null = Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption
        }
    }

    $Exemptions = ConvertTo-HashTable $plan.exemptions.replace
    if ($Exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create replaced Exemptions ($($Exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($exemptionId in $Exemptions.Keys) {
            $exemption = $Exemptions.$exemptionId
            $null = Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption
        }
    }

    $Exemptions = (ConvertTo-HashTable $plan.exemptions.update)
    if ($Exemptions.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Exemptions ($($Exemptions.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($exemptionId in $Exemptions.Keys) {
            $exemption = $Exemptions.$exemptionId
            $null = Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption
        }
    }

    #endregion

}
