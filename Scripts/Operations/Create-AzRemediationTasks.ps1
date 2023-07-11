<#
.SYNOPSIS
Creates remediation tasks for all non-compliant resources in the current tenant.

.PARAMETER PacEnvironmentSelector
Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER Interactive
Set to false if used non-Interactive

.PARAMETER OnlyCheckManagedAssignments
Create remediation task only for Policy assignments owned by this Policy as Code repo

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev"

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions"

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -Interactive $false

.LINK
https://learn.microsoft.com/en-us/azure/governance/policy/concepts/remediation-structure
https://docs.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources
https://azure.github.io/enterprise-azure-Policy-as-code/operational-scripts/#build-Policyassignmentdocumentationps1
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-Interactive")]
    [bool] $Interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Create remediation task only for Policy assignments owned by this Policy as Code repo")]
    [switch] $OnlyCheckManagedAssignments
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$PacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
Set-AzCloudTenantSubscription -Cloud $PacEnvironment.cloud -TenantId $PacEnvironment.tenantId -Interactive $PacEnvironment.interactive

$Query = 'policyresources | where type == "microsoft.policyinsights/policystates" | where properties.complianceState == "NonCompliant" and properties.policyDefinitionAction in ( "modify", "deployifnotexists" ) | summarize count() by tostring(properties.policyAssignmentId), tostring(properties.policyDefinitionReferenceId)  | order by properties_policyAssignmentId asc'
$result = @() + (Search-AzGraphAllItems -Query $Query -Scope @{ UseTenantScope = $true } -ProgressItemName "Policy remediation records")
Write-Information ""

$remediationsList = [System.Collections.ArrayList]::new()
# Only create remediation task owned by this Policy as Code repo
$ScopeTable = Get-AzScopeTree -PacEnvironment $PacEnvironment
$DeployedPolicyResources = Get-AzPolicyResources -PacEnvironment $PacEnvironment -ScopeTable $ScopeTable -SkipExemptions -SkipRoleAssignments
$managedAssignments = $DeployedPolicyResources.policyassignments.managed
$AllAssignments = $DeployedPolicyResources.policyassignments.all
$Strategy = $PacEnvironment.desiredState.strategy
foreach ($entry in $result) {
    $PolicyAssignmentId = $entry.properties_policyAssignmentId
    if ($OnlyCheckManagedAssignments) {
        if ($managedAssignments.ContainsKey($PolicyAssignmentId)) {
            $managedAssignment = $managedAssignments.$PolicyAssignmentId
            $AssignmentPacOwner = $managedAssignment.pacOwner
            if ($AssignmentPacOwner -eq "thisPaC" -or ($AssignmentPacOwner -eq "unknownOwner" -and $Strategy -eq "full")) {
                $null = $remediationsList.Add($entry)
            }
        }
    }
    else {
        if ($AllAssignments.ContainsKey($PolicyAssignmentId)) {
            $null = $remediationsList.Add($entry)
        }
    }
}

$numberOfRemediations = $remediationsList.Count
if ($numberOfRemediations -eq 0) {
    Write-Information "==================================================================================================="
    Write-Information "No Remediation Tasks - zero resources need remediation"
    Write-Information "==================================================================================================="
}
else {
    Write-Information "==================================================================================================="
    Write-Information "Creating Remediation Tasks ($($numberOfRemediations))"
    Write-Information "==================================================================================================="

    foreach ($entry in $remediationsList) {
        $PolicyAssignmentId = $entry.properties_policyAssignmentId
        $PolicyDefinitionReferenceId = $entry.properties_policyDefinitionReferenceId
        $count = $entry.count
        $ResourceIdParts = Split-AzPolicyResourceId -Id $PolicyAssignmentId
        $Scope = $ResourceIdParts.scope
        $AssignmentName = $ResourceIdParts.name
        $taskName = "$AssignmentName--$(New-Guid)"
        $shortScope = $Scope
        if ($ResourceIdParts.scopeType -eq "managementGroups") {
            $shortScope = "/managementGroups/$($ResourceIdParts.splits[4]))"
        }
        if ($PolicyDefinitionReferenceId -ne "") {
            Write-Information "Assignment='$($AssignmentName)', scope=$($shortScope), reference=$($PolicyDefinitionReferenceId), nonCompliant=$($count)"
            $null = Start-AzPolicyRemediation -Name $taskName -Scope $Scope -PolicyAssignmentId $PolicyAssignmentId -PolicyDefinitionReferenceId $PolicyDefinitionReferenceId
        }
        else {
            Write-Information "Assignment='$($AssignmentName)', scope=$($shortScope), nonCompliant=$($count)"
            $null = Start-AzPolicyRemediation -Name $taskName -Scope $Scope -PolicyAssignmentId $PolicyAssignmentId
        }
    }
}
Write-Information ""
