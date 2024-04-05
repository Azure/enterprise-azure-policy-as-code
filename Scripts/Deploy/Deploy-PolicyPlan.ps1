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

.PARAMETER VirtualCores
    Number of virtual cores available to deploy Policy objects in parallel. Defaults to 4.

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

    [Parameter(HelpMessage = "Number of virtual cores available to deploy Policy objects in parallel. Defaults to 4.")]
    [Int16] $VirtualCores = 4
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
$throttleLimit = $VirtualCores * 2

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
    Write-Warning "Plan file '$planFile' does not exist, skipping Policy resource deployment."
    Write-Warning "***************************************************************************************************"
    Write-Warning ""
}
else {

    Write-Information "***************************************************************************************************"
    Write-Information "Deploy Policy resources from plan in file '$planFile'"
    Write-Information "Plan created on $($plan.createdOn)."
    Write-Information "***************************************************************************************************"

    #region delete exemptions, assignment, definitions

    $table = ConvertTo-HashTable $plan.exemptions.delete
    $table += ConvertTo-HashTable $plan.exemptions.replace
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete orphaned, deleted, expired and replaced Exemptions ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Write-Information "$($entry.displayName) - $($id)"
                Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyExemptions
            }
        }
        else {
            $funcRemoveAzResourceByIdRestMethod = ${function:Remove-AzResourceByIdRestMethod}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Remove-AzResourceByIdRestMethod}) {
                    ${function:Remove-AzResourceByIdRestMethod} = $using:funcRemoveAzResourceByIdRestMethod
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Write-Information "$($entry.displayName) - $($id)"
                    Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyExemptions
                }
            }
        }
    }

    $table = ConvertTo-HashTable $plan.assignments.delete
    $table += ConvertTo-HashTable $plan.assignments.replace
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed and replaced Assignments ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Write-Information "$($entry.displayName) - $($id)"
                Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyAssignments
            }
        }
        else {
            $funcRemoveAzResourceByIdRestMethod = ${function:Remove-AzResourceByIdRestMethod}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Remove-AzResourceByIdRestMethod}) {
                    ${function:Remove-AzResourceByIdRestMethod} = $using:funcRemoveAzResourceByIdRestMethod
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Write-Information "$($entry.displayName) - $($id)"
                    Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyAssignments
                }
            }
        }
    }

    $table = ConvertTo-HashTable $plan.policySetDefinitions.delete
    $table += ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete removed and replaced Policy Sets ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Write-Information "$($entry.displayName) - $($id)"
                Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policySetDefinitions
            }
        }
        else {
            $funcRemoveAzResourceByIdRestMethod = ${function:Remove-AzResourceByIdRestMethod}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Remove-AzResourceByIdRestMethod}) {
                    ${function:Remove-AzResourceByIdRestMethod} = $using:funcRemoveAzResourceByIdRestMethod
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Write-Information "$($entry.displayName) - $($id)"
                    Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policySetDefinitions
                }
            }
        }
    }

    $table = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete replaced Policies ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Write-Information "$($entry.displayName) - $($id)"
                Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
            }
        }
        else {
            $funcRemoveAzResourceByIdRestMethod = ${function:Remove-AzResourceByIdRestMethod}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Remove-AzResourceByIdRestMethod}) {
                    ${function:Remove-AzResourceByIdRestMethod} = $using:funcRemoveAzResourceByIdRestMethod
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Write-Information "$($entry.displayName) - $($id)"
                    Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
                }
            }
        }
    }

    #endregion

    $table = ConvertTo-HashTable $plan.policyDefinitions.new
    $table += ConvertTo-HashTable $plan.policyDefinitions.replace
    $table += ConvertTo-HashTable $plan.policyDefinitions.update
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create and update Policies ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Set-AzPolicyDefinitionRestMethod -Definition $entry -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
            }
        }
        else {
            $funcSetAzPolicyDefinitionRestMethod = ${function:Set-AzPolicyDefinitionRestMethod}.ToString()
            $funcRemoveNullFields = ${function:Remove-NullFields}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Set-AzPolicyDefinitionRestMethod}) {
                    ${function:Set-AzPolicyDefinitionRestMethod} = $using:funcSetAzPolicyDefinitionRestMethod
                    ${function:Remove-NullFields} = $using:funcRemoveNullFields
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Set-AzPolicyDefinitionRestMethod -Definition $entry -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
                }
            }
        }
    }

    $table = ConvertTo-HashTable $plan.policySetDefinitions.new
    $table += ConvertTo-HashTable $plan.policySetDefinitions.replace
    $table += ConvertTo-HashTable $plan.policySetDefinitions.update
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create and update Policy Sets ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Set-AzPolicySetDefinitionRestMethod -Definition $entry -ApiVersion $pacEnvironment.apiVersions.policySetDefinitions
            }
        }
        else {
            $funcSetAzPolicySetDefinitionRestMethod = ${function:Set-AzPolicySetDefinitionRestMethod}.ToString()
            $funcRemoveNullFields = ${function:Remove-NullFields}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Set-AzPolicySetDefinitionRestMethod}) {
                    ${function:Set-AzPolicySetDefinitionRestMethod} = $using:funcSetAzPolicySetDefinitionRestMethod
                    ${function:Remove-NullFields} = $using:funcRemoveNullFields
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Set-AzPolicySetDefinitionRestMethod -Definition $entry -ApiVersion $pacEnvironment.apiVersions.policySetDefinitions
                }
            }
        }
    }

    # Policy Sets are updated, can now delete the obsolete Policies
    $table = ConvertTo-HashTable $plan.policyDefinitions.delete
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Delete Policies ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Write-Information $entry.displayName
                Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
            }
        }
        else {
            $funcRemoveAzResourceByIdRestMethod = ${function:Remove-AzResourceByIdRestMethod}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Remove-AzResourceByIdRestMethod}) {
                    ${function:Remove-AzResourceByIdRestMethod} = $using:funcRemoveAzResourceByIdRestMethod
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Write-Information "$($entry.displayName) - $($id)"
                    Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
                }
            }
        }
    }

    $table = ConvertTo-HashTable $plan.assignments.new
    $table += ConvertTo-HashTable $plan.assignments.replace
    $table += ConvertTo-HashTable $plan.assignments.update
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create and update Assignments ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($id in $chunk.Keys) {
                $entry = $chunk.$id
                Set-AzPolicyAssignmentRestMethod -Assignment $entry -ApiVersion $pacEnvironment.apiVersions.policyAssignments
            }
        }
        else {
            $funcSetAzPolicyAssignmentRestMethod = ${function:Set-AzPolicyAssignmentRestMethod}.ToString()
            $funcGetDeepClone = ${function:Get-ClonedObject}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Set-AzPolicyAssignmentRestMethod}) {
                    ${function:Set-AzPolicyAssignmentRestMethod} = $using:funcSetAzPolicyAssignmentRestMethod
                    ${function:Get-ClonedObject} = $using:funcGetDeepClone
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($id in $_.Keys) {
                    $entry = $_.$id
                    Set-AzPolicyAssignmentRestMethod -Assignment $entry -ApiVersion $pacEnvironment.apiVersions.policyAssignments
                }
            }
        }
    }

    $table = ConvertTo-HashTable $plan.exemptions.new
    $table += ConvertTo-HashTable $plan.exemptions.replace
    $table += ConvertTo-HashTable $plan.exemptions.update
    if ($table.psbase.Count -gt 0) {
        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Create and update Exemptions ($($table.psbase.Count))"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $chunks = Split-HashtableIntoChunks -Table $table -NumberOfChunks $throttleLimit -MinChunkingSize 10
        if ($chunks.psbase.Count -eq 1) {
            $chunk = $chunks[0]
            foreach ($exemptionId in $chunk.Keys) {
                $entry = $chunk.$exemptionId
                Set-AzPolicyExemptionRestMethod -ExemptionObj $entry -ApiVersion $pacEnvironment.apiVersions.policyExemptions
            }
        }
        else {
            $funcSetAzPolicyExemptionRestMethod = ${function:Set-AzPolicyExemptionRestMethod}.ToString()
            $funcRemoveNullFields = ${function:Remove-NullFields}.ToString()
            $chunks | ForEach-Object -ThrottleLimit $throttleLimit -Parallel {
                if ($null -eq ${function:Set-AzPolicyExemptionRestMethod}) {
                    ${function:Set-AzPolicyExemptionRestMethod} = $using:funcSetAzPolicyExemptionRestMethod
                    ${function:Remove-NullFields} = $using:funcRemoveNullFields
                }
                $pacEnvironment = $using:pacEnvironment
                foreach ($exemptionId in $_.Keys) {
                    $entry = $_.$exemptionId
                    Set-AzPolicyExemptionRestMethod -ExemptionObj $entry -ApiVersion $pacEnvironment.apiVersions.policyExemptions
                }
            }
        }
    }
    Write-Information ""
    Write-Information "***************************************************************************************************"
    Write-Information "Policy resources deployed from plan in file '$planFile'"
    Write-Information "***************************************************************************************************"
}
