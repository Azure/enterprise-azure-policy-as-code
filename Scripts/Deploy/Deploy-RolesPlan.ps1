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
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("pid-cf031290-b7d4-48ef-9ff5-4dcd7bff8c6c") 
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

$planFile = $pacEnvironment.rolesPlanInputFile
$plan = Get-DeploymentPlan -PlanFile $planFile -AsHashTable

if ($null -eq $plan) {
    Write-Warning "***************************************************************************************************"
    Write-Warning "Plan does not exist, skip Role assignments deployment."
    Write-Warning "***************************************************************************************************"
    Write-Warning ""
}
else {

    Write-Information "***************************************************************************************************"
    Write-Information "Deploy Role assignments from plan in file '$planFile'"
    Write-Information "Plan created on $($plan.createdOn)."
    Write-Information "***************************************************************************************************"

    $removedRoleAssignments = $plan.roleAssignments.removed
    $addedRoleAssignments = $plan.roleAssignments.added
    if ($removedRoleAssignments.psbase.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Remove ($($removedRoleAssignments.psbase.Count)) obsolete Role assignments"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $splatTransform = "principalId/ObjectId scope/Scope roleDefinitionId/RoleDefinitionId"
        foreach ($roleAssignment in $removedRoleAssignments) {
            Write-Information "$($roleAssignment.displayName): $($roleAssignment.roleDisplayName)($($roleAssignment.roleDefinitionId)) at $($roleAssignment.scope)"
            $splat = Get-FilteredHashTable $roleAssignment -SplatTransform $splatTransform
            $null = Remove-AzRoleAssignment @splat -WarningAction SilentlyContinue
        }
        Write-Information ""
    }

    if ($addedRoleAssignments.psbase.Count -gt 0) {
        Write-Information "==================================================================================================="
        Write-Information "Add ($($addedRoleAssignments.psbase.Count)) new Role assignments"
        Write-Information "---------------------------------------------------------------------------------------------------"
        $retriesLimit = 4
        $splatTransform = "principalId/ObjectId objectType/ObjectType scope/Scope roleDefinitionId/RoleDefinitionId"
        $identitiesByAssignmentId = @{}
        foreach ($roleAssignment in $addedRoleAssignments) {
            $principalId = $roleAssignment.principalId
            if ($null -eq $principalId) {
                $policyAssignmentId = $roleAssignment.assignmentId
                $identity = $null
                if ($identitiesByAssignmentId.ContainsKey($policyAssignmentId)) {
                    $identity = $identitiesByAssignmentId.$policyAssignmentId
                }
                else {
                    $policyAssignment = Get-AzPolicyAssignment -Id $roleAssignment.assignmentId -WarningAction SilentlyContinue
                    $identity = $policyAssignment.Identity
                    $null = $identitiesByAssignmentId.Add($policyAssignmentId, $identity)
                }
                $principalId = $identity.PrincipalId
                $roleAssignment.principalId = $principalId
            }
            Write-Information "$($policyAssignment.Properties.displayName): $($roleAssignment.roleDisplayName)($($roleAssignment.roleDefinitionId)) at $($roleAssignment.scope)"
            $splat = Get-FilteredHashTable $roleAssignment -SplatTransform $splatTransform
            if (Get-AzRoleAssignment -Scope $splat.Scope -ObjectId $splat.ObjectId -RoleDefinitionId $splat.RoleDefinitionId) {
                Write-Information "Role assignment already exists"
            }
            else {
                while ($retries -le $retriesLimit) {

                    $result = New-AzRoleAssignment @splat -WarningAction SilentlyContinue
                    if ($null -ne $result) {
                        break
                    }
                    else {
                        Start-Sleep -Seconds 10
                        $retries++
                    }
                }
            }
            
        }
    }
    Write-Information ""
}
