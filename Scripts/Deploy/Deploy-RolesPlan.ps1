#Requires -PSEdition Core
<#
.SYNOPSIS 
    Deploys Role assignments from a plan file.  

.PARAMETER PacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER InputFolder
    Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.

.PARAMETER Interactive
    Use switch to indicate interactive use

.EXAMPLE
    Deploy-RolesPlan.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\PAC\Definitions" -InputFolder "C:\PAC\Output" -Interactive
    Deploys Role assignments from a plan file.

.EXAMPLE
    Deploy-RolesPlan.ps1 -Interactive
    Deploys Role assignments from a plan file. The script prompts for the PAC environment and uses the default definitions and input folders.

.LINK
    https://azure.github.io/enterprise-azure-policy-as-code/#deployment-scripts

#>

[CmdletBinding()]
param (
    [parameter(HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.",
        Position = 0
    )]
    [string] $PacEnvironmentSelector,

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(HelpMessage = "Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER, `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$InputFolder,

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
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -InputFolder $InputFolder  -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive -DeploymentDefaultContext $pacEnvironment.defaultContext

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    Submit-EPACTelemetry -Cuapid "pid-cf031290-b7d4-48ef-9ff5-4dcd7bff8c6c" -DeploymentRootScope $pacEnvironment.deploymentRootScope
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

$planFile = $pacEnvironment.rolesPlanInputFile
$plan = Get-DeploymentPlan -PlanFile $planFile -AsHashTable

if ($null -eq $plan) {
    Write-Warning "***************************************************************************************************"
    Write-Warning "Plan file $planFile does not exist, skip Role assignments deployment."
    Write-Warning "***************************************************************************************************"
    Write-Warning ""
}
else {

    Write-Information "***************************************************************************************************"
    Write-Information "Deploy Role assignments from plan in file '$planFile'"
    Write-Information "Plan created on $($plan.createdOn)."
    Write-Information "***************************************************************************************************"
    Write-Information ""

    $addedRoleAssignments = $plan.roleAssignments.added
    $updatedRoleAssignments = $plan.roleAssignments.updated 
    $removedRoleAssignments = $plan.roleAssignments.removed
    if ($removedRoleAssignments.psbase.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Remove ($($removedRoleAssignments.psbase.Count)) obsolete Role assignments"
        Write-Information "---------------------------------------------------------------------------------------------------"
        foreach ($roleAssignment in $removedRoleAssignments) {
            Write-Information "PrincipalId $($roleAssignment.principalId), role $($roleAssignment.roleDisplayName)($($roleAssignment.roleDefinitionId)) at $($roleAssignment.scope)"
            if (!$roleAssignment.crossTenant) {
                $null = Remove-AzRoleAssignmentRestMethod -RoleAssignmentId $roleAssignment.id -ApiVersion $pacEnvironment.apiVersions.roleAssignments
            }
            else {
                $null = Remove-AzRoleAssignmentRestMethod -RoleAssignmentId $roleAssignment.id -TenantId $pacEnvironment.managingTenantId -ApiVersion $pacEnvironment.apiVersions.roleAssignments
            }

        }
        Write-Information ""
    }

    if ($addedRoleAssignments.psbase.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Add ($($addedRoleAssignments.psbase.Count)) new Role assignments"
        Write-Information "---------------------------------------------------------------------------------------------------"

        # Get identities for policy assignments from plan or by calling the REST API to retrieve the Policy Assignment
        $assignmentById = @{}
        foreach ($roleAssignment in $addedRoleAssignments) {
            $principalId = $roleAssignment.properties.principalId
            $policyAssignmentId = $roleAssignment.assignmentId
            if ($null -eq $principalId) {
                $identity = $null
                $principalId = ""
                if ($assignmentById.ContainsKey($policyAssignmentId)) {
                    $principalId = $assignmentById[$policyAssignmentId]
                }
                else {
                    $policyAssignment = Get-AzPolicyAssignmentRestMethod -AssignmentId $policyAssignmentId -ApiVersion $pacEnvironment.apiVersions.policyAssignments
                    $identity = $policyAssignment.identity
                    if ($identity -and $identity.type -ne "None") {
                        $principalId = ""
                        if ($identity.type -eq "SystemAssigned") {
                            $principalId = $identity.principalId
                        }
                        else {
                            $userAssignedIdentityId = $identity.userAssignedIdentities.PSObject.Properties.Name
                            $principalId = $identity.userAssignedIdentities.$userAssignedIdentityId.principalId
                        }
                    }
                    else {
                        Write-Error "Identity not found for assignment '$($policyAssignmentId)'" -ErrorAction Stop
                    }
                    $null = $assignmentById.Add($policyAssignmentId, $principalId)
                }
                $roleAssignment.properties.principalId = $principalId
            }
            elseif (-not $assignmentById.ContainsKey($policyAssignmentId)) {
                $null = $assignmentById.Add($policyAssignmentId, $principalId)
            }
            Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -ApiVersion $pacEnvironment.apiVersions.roleAssignments
        }
        Write-Information ""
    }
    if ($updatedRoleAssignments.psbase.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Update ($($updatedRoleAssignments.psbase.Count)) Role assignments"
        Write-Information "---------------------------------------------------------------------------------------------------"

        # Get identities for policy assignments from plan or by calling the REST API to retrieve the Policy Assignment
        foreach ($roleAssignment in $updatedRoleAssignments) {
            Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -ApiVersion $pacEnvironment.apiVersions.roleAssignments
        }
        Write-Information ""
    }
}
