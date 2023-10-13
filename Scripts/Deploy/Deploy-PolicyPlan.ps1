#Requires -PSEdition Core

<#
.SYNOPSIS
    Deploys Policy resources from a plan file.

.PARAMETER PacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER InputFolder
    Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.

.PARAMETER Interactive
    Use switch to indicate interactive use

.PARAMETER IgnoreScopeLockedErrors
    Ignore errors raised by locked scopes

.EXAMPLE
    Deploy-PolicyPlan.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -InputFolder "C:\git\policy-as-code\Output" -Interactive
    Deploys Policy resources from a plan file.

.EXAMPLE
    Deploy-PolicyPlan.ps1 -PacEnvironmentSelector "dev" -Interactive
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
    [string] $PacEnvironmentSelector,

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(HelpMessage = "Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string] $InputFolder,

    [Parameter(HelpMessage = "Use switch to indicate interactive use")]
    [switch] $Interactive,

    [Parameter(HelpMessage = "Ignore errors raised by locked scopes")]
    [switch] $IgnoreScopeLockedErrors
)

$PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
}

Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -InputFolder $InputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("pid-fe9ff1e8-5521-4b9d-ab1d-84e15447565e") 
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

$planFile = $pacEnvironment.policyPlanInputFile
$plan = Get-DeploymentPlan -PlanFile $planFile
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
            try {
                $null = Remove-AzPolicyExemption -Id $id -Force -ErrorAction Stop
            }
            catch {
                if ($IgnoreScopeLockedErrors -and $_.Exception.Message -match "^ScopeLocked") {
                    Write-Warning "Scope is locked - error output: $($_.Exception.Message)"
                }
                else {
                    throw $_
                }
            }
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
            try {
                $null = Remove-AzPolicyExemption -Id $id -Force -ErrorAction Stop
            }
            catch {
                if ($IgnoreScopeLockedErrors -and $_.Exception.Message -match "^ScopeLocked") {
                    Write-Warning "Scope is locked - error output: $($_.Exception.Message)"
                }
                else {
                    throw $_
                }
            }
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
            Set-AzPolicyDefinitionRestMethod -Definition $definitionObj
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
            Set-AzPolicyDefinitionRestMethod -Definition $definitionObj
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
            Set-AzPolicyDefinitionRestMethod -Definition $definitionObj
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
            Set-AzPolicySetDefinitionRestMethod -Definition $definitionObj
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
            Set-AzPolicySetDefinitionRestMethod -Definition $definitionObj
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
            Set-AzPolicySetDefinitionRestMethod -Definition $definitionObj
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
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -Assignment $_ -CurrentDisplayName $currentDisplayName
        }
    }

    if ($replaceAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Recreate replaced Assignments ($($replaceAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $replaceAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -Assignment $_ -CurrentDisplayName $currentDisplayName
        }
    }

    if ($updateAssignments.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Update Assignments ($($updateAssignments.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $currentDisplayName = "-"
        $updateAssignments.Values | Sort-Object -Property { $_.displayName } | ForEach-Object -Process {
            $currentDisplayName = Set-AzPolicyAssignmentRestMethod -Assignment $_ -CurrentDisplayName $currentDisplayName
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
            Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption
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
            Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption
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
            Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption
        }
    }

    #endregion

}
