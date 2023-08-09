<#
.SYNOPSIS
Creates remediation tasks for all non-compliant resources in the current tenant.

.PARAMETER PacEnvironmentSelector
Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER Interactive
Set to false if used non-interactive

.PARAMETER OnlyCheckManagedAssignments
Include non-compliance data only for Policy assignments owned by this Policy as Code repo

.PARAMETER PolicyDefinitionFilter
Filter by Policy definition names (array) or ids (array).

.PARAMETER PolicySetDefinitionFilter
Filter by Policy Set definition names (array) or ids (array).

.PARAMETER PolicyAssignmentFilter
Filter by Policy Assignment names (array) or ids (array).

.PARAMETER PolicyEffectFilter
Filter by Policy effect (array).

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev"

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions"

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -Interactive $false

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -OnlyCheckManagedAssignments

.EXAMPLE
Create-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -PolicyDefinitionFilter "Require tag 'Owner' on resource groups" -PolicySetDefinitionFilter "Require tag 'Owner' on resource groups" -PolicyAssignmentFilter "Require tag 'Owner' on resource groups"

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
    [bool] $Interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Create remediation task only for Policy assignments owned by this Policy as Code repo")]
    [switch] $OnlyCheckManagedAssignments,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy definition names or ids")]
    [string[]] $PolicyDefinitionFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Set definition names or ids")]
    [string[]] $PolicySetDefinitionFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Assignment names or ids")]
    [string[]] $PolicyAssignmentFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Effect")]
    [string[]] $PolicyEffectFilter = $null
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# Make a local of the parameters
$onlyCheckManagedAssignments = $OnlyCheckManagedAssignments.IsPresent
$policySetDefinitionFilter = $PolicySetDefinitionFilter
$policyAssignmentFilter = $PolicyAssignmentFilter
$policyEffectFilter = $PolicyEffectFilter

# Setting the local copies of parameters to simplify debugging
# $onlyCheckManagedAssignments = $true
# $policySetDefinitionFilter = @( "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111" )
# $policyAssignmentFilter = @( "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb" )
# $policyEffectFilter = @( "deployifnotexists" )

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive

$rawNonCompliantList, $deployedPolicyResources, $scopeTable = Find-AzNonCompliantResources `
    -RemediationOnly `
    -PacEnvironment $pacEnvironment `
    -OnlyCheckManagedAssignments:$onlyCheckManagedAssignments `
    -PolicyDefinitionFilter:$policyDefinitionFilter `
    -PolicySetDefinitionFilter:$policySetDefinitionFilter `
    -PolicyAssignmentFilter:$policyAssignmentFilter `
    -PolicyEffectFilter $policyEffectFilter

Write-Information "==================================================================================================="
Write-Information "Collating non-compliant resources by Assignment Id and (if Policy Set) policyDefintionReferenceId"
Write-Information "==================================================================================================="


$total = $rawNonCompliantList.Count
if ($total -eq 0) {
    Write-Information "No non-compliant resources found - no remediation tasks created"
}
else {
    Write-Information "Processing $total non-compliant resources"

    $collatedByAssignmentId = @{}
    $allPolicyDefinitions = $deployedPolicyResources.policydefinitions.all
    foreach ($entry in $rawNonCompliantList) {
        $entryProperties = $entry.properties
        $policyAssignmentId = $entryProperties.policyAssignmentId
        $policyAssignmentName = $entryProperties.policyAssignmentName
        $policyAssignmentScope = $entryProperties.policyAssignmentScope
        $policyDefinitionId = $entryProperties.policyDefinitionId
        $policyDefinitionReferenceId = $entryProperties.policyDefinitionReferenceId
        $policyDefinitionAction = $entryProperties.policyDefinitionAction
        $policyDefinitionName = $entryProperties.policyDefinitionName
        $policyDefinition = $null
        $policyDefinitionProperties = @{}
        $category = "|unknown|"
        if ($allPolicyDefinitions.ContainsKey($policyDefinitionId)) {
            $policyDefinition = $allPolicyDefinitions.$policyDefinitionId
            $policyDefinitionProperties = Get-PolicyResourceProperties $policyDefinition
            if ($policyDefinitionProperties.displayName) {
                $policyDefinitionName = $policyDefinitionProperties.displayName
            }
            $metadata = $policyDefinitionProperties.metadata
            if ($metadata) {
                if ($metadata.category) {
                    $category = $metadata.category
                }
            }
        }
        $taskName = "$policyAssignmentName-$(New-Guid)"
        $shortScope = $policyAssignmentScope
        $resourceIdParts = Split-AzPolicyResourceId -Id $policyAssignmentId
        if ($resourceIdParts.scopeType -eq "managementGroups") {
            $shortScope = "/mg/$($resourceIdParts.splits[4]))"
        }

        $parametersSplat = $null
        if ($policyDefinitionReferenceId -and $policyDefinitionReferenceId -ne "") {
            $parametersSplat = [ordered]@{
                Name                        = $taskName
                Scope                       = $policyAssignmentScope
                PolicyAssignmentId          = $policyAssignmentId
                PolicyDefinitionReferenceId = $policyDefinitionReferenceId
                ResourceDiscoveryMode       = "ExistingNonCompliant"
                ResourceCount               = 50000
                ParallelDeploymentCount     = 30
            }
        }
        else {
            $parametersSplat = [ordered]@{
                Name                    = $taskName
                Scope                   = $policyAssignmentScope
                PolicyAssignmentId      = $policyAssignmentId
                ResourceDiscoveryMode   = "ExistingNonCompliant"
                ResourceCount           = 50000
                ParallelDeploymentCount = 30
            }
        }

        $key = "$policyAssignmentId|$policyDefinitionReferenceId"
        if (-not $collatedByAssignmentId.ContainsKey($key)) {
            $remediationEntry = @{
                policyAssignmentId          = $policyAssignmentId
                policyAssignmentName        = $policyAssignmentName
                shortScope                  = $shortScope
                policyDefinitionReferenceId = $policyDefinitionReferenceId
                category                    = $category
                policyDefinitionName        = $policyDefinitionName
                policyDefinitionAction      = $policyDefinitionAction
                resourceCount               = 1
                parametersSplat             = $parametersSplat
            }
            $null = $collatedByAssignmentId.Add($key, $remediationEntry)
        }
        else {
            $collatedByAssignmentId.$key.resourceCount += 1
        }
    }

    Write-Information ""
    Write-Information "--- Creating $($collatedByAssignmentId.Count) remediation tasks sorted by Assignment Id and (if Policy Set) Category and Policy Name ---"

    $collatedByAssignmentId.Values | Sort-Object { $_.policyAssignmentId }, { $_.category }, { $_.policyName } | ForEach-Object {
        if ($_.policyDefinitionReferenceId) {
            Write-Information "'$($_.shortScope)/$($_.policyAssignmentName)|$($_.policyDefinitionReferenceId)': $($_.resourceCount) resources, '$($_.policyDefinitionName)', $($_.policyDefinitionAction)"
        }
        else {
            Write-Information "'$($_.shortScope)/$($_.policyAssignmentName)': $($_.resourceCount) resources, '$($_.policyDefinitionName)', $($_.policyDefinitionAction)"
        }
        $parameters = $_.parametersSplat
        Write-Verbose "Parameters: $($parameters | ConvertTo-Json -Depth 99)"
        $null = Start-AzPolicyRemediation @parameters
    }
}
Write-Information ""
