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

.PARAMETER SkipExemptions
    If set, do not deploy the exemptions plan.

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

    [Parameter(HelpMessage = "If set, do not deploy the exemptions plan.")]
    [switch] $SkipExemptions,

    [Parameter(HelpMessage = "Set true to fail the pipeline and deployment if a 403 error occurs during creation and updates of exemptions.")]
    [bool] $FailOnExemptionError = $false
)

$PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
}

Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$scriptStartTime = Get-Date

# Display welcome header
Write-ModernHeader -Title "Enterprise Policy as Code (EPAC)" -Subtitle "Deploying Policy Plan" -HeaderColor Magenta -SubtitleColor DarkMagenta

$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -InputFolder $InputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive -DeploymentDefaultContext $pacEnvironment.defaultContext

# Display environment information
Write-ModernSection -Title "Environment Configuration" -Color Blue
Write-ModernStatus -Message "PAC Environment: $($pacEnvironment.pacSelector)" -Status "info" -Indent 2
Write-ModernStatus -Message "Deployment Root: $($pacEnvironment.deploymentRootScope)" -Status "info" -Indent 2
Write-ModernStatus -Message "Input Folder: $InputFolder" -Status "info" -Indent 2

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-ModernStatus -Message "Telemetry is enabled" -Status "info" -Indent 2
    Submit-EPACTelemetry -Cuapid "pid-fe9ff1e8-5521-4b9d-ab1d-84e15447565e" -DeploymentRootScope $pacEnvironment.deploymentRootScope
}
else {
    Write-ModernStatus -Message "Telemetry is disabled" -Status "info" -Indent 2
}

$planFile = $pacEnvironment.policyPlanInputFile
$plan = Get-DeploymentPlan -PlanFile $planFile
if ($null -eq $plan) {
    Write-ModernSection -Title "Deployment Status" -Color Red
    Write-ModernStatus -Message "Plan file '$planFile' does not exist, skipping Policy resource deployment" -Status "error" -Indent 2
    exit
}
else {
    Write-ModernSection -Title "Deployment Plan Loaded" -Color Green
    Write-ModernStatus -Message "Plan file: $planFile" -Status "success" -Indent 2
    Write-ModernStatus -Message "Plan created on: $($plan.createdOn)" -Status "info" -Indent 2

    #region delete exemptions, assignment, definitions

    if (-not $SkipExemptions) {
        $table = ConvertTo-HashTable $plan.exemptions.delete
        $table += ConvertTo-HashTable $plan.exemptions.replace
        if ($table.psbase.Count -gt 0) {
            Write-ModernSection -Title "Deleting Policy Exemptions" -Color Red
            Write-ModernStatus -Message "Removing $($table.psbase.Count) orphaned, deleted, expired and replaced exemptions" -Status "info" -Indent 2
            foreach ($id in $table.Keys) {
                $entry = $table.$id
                Write-ModernStatus -Message "$($entry.displayName) - $($id)" -Status "info" -Indent 4
                Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyExemptions
            }
        }
    }
    $table = ConvertTo-HashTable $plan.assignments.delete
    $table += ConvertTo-HashTable $plan.assignments.replace
    if ($table.psbase.Count -gt 0) {
        Write-ModernSection -Title "Deleting Policy Assignments ($($table.psbase.Count) items)" -Color Red
        foreach ($id in $table.Keys) {
            $entry = $table.$id
            Write-ModernStatus -Message "$($entry.displayName)" -Status "info" -Indent 2
            Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyAssignments
        }
    }

    $table = ConvertTo-HashTable $plan.policySetDefinitions.delete
    $table += ConvertTo-HashTable $plan.policySetDefinitions.replace
    if ($table.psbase.Count -gt 0) {
        Write-ModernSection -Title "Deleting Policy Set Definitions" -Color Red
        Write-ModernStatus -Message "Removing $($table.psbase.Count) removed and replaced policy sets" -Status "info" -Indent 2
        foreach ($id in $table.Keys) {
            $entry = $table.$id
            Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policySetDefinitions
        }
    }

    $table = ConvertTo-HashTable $plan.policyDefinitions.replace
    if ($table.psbase.Count -gt 0) {
        Write-ModernSection -Title "Deleting Replaced Policies ($($table.psbase.Count) items)" -Color Red
        foreach ($id in $table.Keys) {
            $entry = $table.$id
            Write-ModernStatus -Message "Removing:`n    Display Name: $($entry.displayName)`n    ID: $id" -Status "pending" -Indent 2
            Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
        }
    }

    #endregion

    $table = ConvertTo-HashTable $plan.policyDefinitions.new
    $table += ConvertTo-HashTable $plan.policyDefinitions.replace
    $table += ConvertTo-HashTable $plan.policyDefinitions.update
    if ($table.psbase.Count -gt 0) {
        Write-ModernSection -Title "Creating and Updating Policies ($($table.psbase.Count) items)" -Color Blue
        foreach ($id in $table.Keys) {
            $entry = $table.$id
            Write-ModernStatus -Message "Processing: $($entry.displayName)" -Status "pending" -Indent 2
            Set-AzPolicyDefinitionRestMethod -Definition $entry -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
            Write-ModernStatus -Message "Completed: $($entry.displayName)" -Status "success" -Indent 2
            Write-Information ""
        }
    }

    $table = ConvertTo-HashTable $plan.policySetDefinitions.new
    $table += ConvertTo-HashTable $plan.policySetDefinitions.replace
    $table += ConvertTo-HashTable $plan.policySetDefinitions.update
    if ($table.psbase.Count -gt 0) {
        Write-ModernSection -Title "Creating and Updating Policy Sets ($($table.psbase.Count) items)" -Color Green
        foreach ($id in $table.Keys) {
            $entry = $table.$id
            Write-ModernStatus -Message "Processing: $($entry.displayName)" -Status "pending" -Indent 2
            Set-AzPolicySetDefinitionRestMethod -Definition $entry -ApiVersion $pacEnvironment.apiVersions.policySetDefinitions
            Write-ModernStatus -Message "Completed: $($entry.displayName)" -Status "success" -Indent 2
            Write-Information ""
        }
    }

    # Policy Sets are updated, can now delete the obsolete Policies
    $table = ConvertTo-HashTable $plan.policyDefinitions.delete
    if ($table.psbase.Count -gt 0) {
        Write-ModernSection -Title "Deleting Obsolete Policies ($($table.psbase.Count) items)" -Color Red
        foreach ($id in $table.Keys) {
            $entry = $table.$id
            Write-ModernStatus -Message "Removing:`n    Display Name: $($entry.displayName)`n    ID: $id" -Status "pending" -Indent 2
            Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $pacEnvironment.apiVersions.policyDefinitions
        }
    }

    $table = ConvertTo-HashTable $plan.assignments.new
    $table += ConvertTo-HashTable $plan.assignments.replace
    $table += ConvertTo-HashTable $plan.assignments.update
    if ($table.psbase.Count -gt 0) {
        Write-ModernSection -Title "Creating and Updating Assignments ($($table.psbase.Count) items)" -Color Yellow
        foreach ($id in $table.Keys) {
            $entry = $table.$id
            Write-ModernStatus -Message "Processing: $($entry.displayName)" -Status "pending" -Indent 2
            Set-AzPolicyAssignmentRestMethod -Assignment $entry -ApiVersion $pacEnvironment.apiVersions.policyAssignments
            Write-ModernStatus -Message "Completed: $($entry.displayName)" -Status "success" -Indent 4
            Write-Information ""
        }
    }

    if (-not $SkipExemptions) {
        $table = ConvertTo-HashTable $plan.exemptions.new
        $table += ConvertTo-HashTable $plan.exemptions.replace
        $table += ConvertTo-HashTable $plan.exemptions.update
        if ($table.psbase.Count -gt 0) {
            Write-ModernSection -Title "Creating and Updating Exemptions ($($table.psbase.Count) items)" -Color Cyan
            foreach ($exemptionId in $table.Keys) {
                $entry = $table.$exemptionId
                Write-ModernStatus -Message "Processing: $($entry.displayName)" -Status "pending" -Indent 2
                Set-AzPolicyExemptionRestMethod -ExemptionObj $entry -ApiVersion $pacEnvironment.apiVersions.policyExemptions -FailOnExemptionError $FailOnExemptionError
                Write-ModernStatus -Message "Completed: $($entry.displayName)" -Status "success" -Indent 2
                Write-Information ""
            }
        }
    }
    
    # Calculate execution time
    $scriptEndTime = Get-Date
    $executionTime = $scriptEndTime - $scriptStartTime
    
    # Display completion summary
    Write-ModernSection -Title "Deployment Complete" -Color Green
    Write-ModernStatus -Message "Plan file: $planFile" -Status "success" -Indent 2
    Write-ModernStatus -Message "Execution time: $($executionTime.ToString('mm\:ss'))" -Status "info" -Indent 2
    Write-ModernStatus -Message "All policy resources have been successfully deployed" -Status "success" -Indent 2
}
