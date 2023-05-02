<#
.SYNOPSIS
Creates remediation tasks for all non-compliant resources in the current tenant.

.PARAMETER PacEnvironmentSelector
Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER interactive
Set to false if used non-interactive

.PARAMETER onlyCheckManagedAssignments
Create remediation task only for Policy assignments owned by this Policy as Code repo

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev"

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions"

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -interactive $false

.LINK
https://learn.microsoft.com/en-us/azure/governance/policy/concepts/remediation-structure
https://docs.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources
https://azure.github.io/enterprise-azure-policy-as-code/operational-scripts/#build-policyassignmentdocumentationps1
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Create remediation task only for Policy assignments owned by this Policy as Code repo")]
    [switch] $onlyCheckManagedAssignments
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive

$query = 'policyresources | where type == "microsoft.policyinsights/policystates" | where properties.complianceState == "NonCompliant" and properties.policyDefinitionAction in ( "modify", "deployifnotexists" ) | summarize count() by tostring(properties.policyAssignmentId), tostring(properties.policyDefinitionReferenceId)  | order by properties_policyAssignmentId asc'
$result = @() + (Search-AzGraphAllItems -query $query -scope @{ UseTenantScope = $true } -progressItemName "Policy remediation records")
Write-Information ""

$remediationsList = [System.Collections.ArrayList]::new()
# Only create remediation task owned by this Policy as Code repo
$scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
$deployedPolicyResources = Get-AzPolicyResources -pacEnvironment $pacEnvironment -scopeTable $scopeTable -skipExemptions -skipRoleAssignments
$managedAssignments = $deployedPolicyResources.policyassignments.managed
$allAssignments = $deployedPolicyResources.policyassignments.all
$strategy = $pacEnvironment.desiredState.strategy
foreach ($entry in $result) {
    $policyAssignmentId = $entry.properties_policyAssignmentId
    if ($onlyCheckManagedAssignments) {
        if ($managedAssignments.ContainsKey($policyAssignmentId)) {
            $managedAssignment = $managedAssignments.$policyAssignmentId
            $assignmentPacOwner = $managedAssignment.pacOwner
            if ($assignmentPacOwner -eq "thisPaC" -or ($assignmentPacOwner -eq "unknownOwner" -and $strategy -eq "full")) {
                $null = $remediationsList.Add($entry)
            }
        }
    }
    else {
        if ($allAssignments.ContainsKey($policyAssignmentId)) {
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
        $policyAssignmentId = $entry.properties_policyAssignmentId
        $policyDefinitionReferenceId = $entry.properties_policyDefinitionReferenceId
        $count = $entry.count
        $resourceIdParts = Split-AzPolicyResourceId -id $policyAssignmentId
        $scope = $resourceIdParts.scope
        $assignmentName = $resourceIdParts.name
        $taskName = "$assignmentName--$(New-Guid)"
        $shortScope = $scope
        if ($resourceIdParts.scopeType -eq "managementGroups") {
            $shortScope = "/managementGroups/$($resourceIdParts.splits[4]))"
        }
        if ($policyDefinitionReferenceId -ne "") {
            Write-Information "Assignment='$($assignmentName)', scope=$($shortScope), reference=$($policyDefinitionReferenceId), nonCompliant=$($count)"
            $null = Start-AzPolicyRemediation -Name $taskName -Scope $scope -PolicyAssignmentId $policyAssignmentId -PolicyDefinitionReferenceId $policyDefinitionReferenceId
        }
        else {
            Write-Information "Assignment='$($assignmentName)', scope=$($shortScope), nonCompliant=$($count)"
            $null = Start-AzPolicyRemediation -Name $taskName -Scope $scope -PolicyAssignmentId $policyAssignmentId
        }
    }
}
Write-Information ""
