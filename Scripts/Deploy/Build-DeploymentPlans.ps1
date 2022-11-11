#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $pacEnvironmentSelector,

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder,

    [Parameter(HelpMessage = "Output folder path for plan files. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$outputFolder,

    [Parameter(HelpMessage = "Script is used interactively. Script can prompt the interactive user for input.")]
    [switch] $interactive,

    [Parameter(HelpMessage = "If set, outputs variables consumable by conditions in a DevOps pipeline.")]
    [ValidateSet(“ado”, ”gitlab”, ””)]
    [string] $devOpsType = ""
)

# Load cmdlets
. "$PSScriptRoot/../Helpers/Build-AssignmentCsvAndJsonParameters.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentDefinitionAtLeaf.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentDefinitionEntry.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentDefinitionNode.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentParameterObject.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentRoleChanges.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-ExemptionsPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-PolicyPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-PolicySetPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-PolicySetPolicyDefinitionIds.ps1"
. "$PSScriptRoot/../Helpers/Build-NotScopes.ps1"

. "$PSScriptRoot/../Helpers/Confirm-AssignmentParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ObjectValueEqualityDeep.ps1"
. "$PSScriptRoot/../Helpers/Confirm-MetadataMatches.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PacOwner.ps1"
. "$PSScriptRoot/../Helpers/Confirm-DeleteForStrategy.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionsUsedMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicySetDefinitionUsedExists.ps1"

. "$PSScriptRoot/../Helpers/Convert-EffectToOrdinal.ps1"
. "$PSScriptRoot/../Helpers/Convert-PolicySetsToDetails.ps1"
. "$PSScriptRoot/../Helpers/Convert-PolicySetsToFlatList.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

. "$PSScriptRoot/../Helpers/Get-AzPolicyResources.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/Get-DeepClone.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Get-HashtableShallowClone"
. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-ParameterNameFromValueString"
. "$PSScriptRoot/../Helpers/Get-PolicyResourceProperties"

. "$PSScriptRoot/../Helpers/Search-AzGraphAllItems.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

# Initialize
$InformationPreference = "Continue"
Install-Module Az.ResourceGraph -Force
Import-Module Az.ResourceGraph -Force
$pacEnvironment = Select-PacEnvironment $pacEnvironmentSelector -definitionsRootFolder $definitionsRootFolder -outputFolder $outputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive

# Getting existing Policy resources
$exemptionsFolderForPacEnvironment = "$($pacEnvironment.policyExemptionsFolder)/$($pacEnvironment.pacSelector)"
$exemptionsAreManaged = Test-Path $exemptionsFolderForPacEnvironment
$exemptionsAreNotManaged = !$exemptionsAreManaged
if ($exemptionsAreNotManaged) {
    Write-Warning "Policy Exemptions folder $($exemptionsFolderForPacEnvironment) not found"
    Write-Warning "Policy Exemptions not managed by this PaC environment $($pacEnvironment.pacSelector)!"
}
$scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
$deployedPolicyResources = Get-AzPolicyResources -pacEnvironment $pacEnvironment -scopeTable $scopeTable -skipExemptions:$exemptionsAreNotManaged

# Process Policy definitions
$policyDefinitions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfChanges = 0
    numberUnchanged = 0
}
$policyRoleIds = @{}
$allDefinitions = @{
    policydefinitions    = @{}
    policysetdefinitions = @{}
}
$replaceDefinitions = @{}
Build-PolicyPlan `
    -definitionsRootFolder $pacEnvironment.policyDefinitionsFolder `
    -pacEnvironment $pacEnvironment `
    -deployedDefinitions $deployedPolicyResources.policydefinitions `
    -definitions $policyDefinitions `
    -allDefinitions $allDefinitions `
    -replaceDefinitions $replaceDefinitions `
    -policyRoleIds $policyRoleIds

# Process Policy Set definitions
$policySetDefinitions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfChanges = 0
    numberUnchanged = 0
}
Build-PolicySetPlan `
    -definitionsRootFolder $pacEnvironment.policySetDefinitionsFolder `
    -pacEnvironment $pacEnvironment `
    -deployedDefinitions $deployedPolicyResources.policysetdefinitions `
    -definitions $policySetDefinitions `
    -allDefinitions $allDefinitions `
    -replaceDefinitions $replaceDefinitions `
    -policyRoleIds $policyRoleIds

# Process Assignment JSON files
$assignments = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfChanges = 0
    numberUnchanged = 0
}
$roleAssignments = @{
    numberOfChanges = 0
    added           = @{}
    removed         = @{}
}
$allAssignments = @{}
Build-AssignmentPlan `
    -assignmentsRootFolder $pacEnvironment.policyAssignmentsFolder `
    -pacEnvironment $pacEnvironment `
    -scopeTable $scopeTable `
    -deployedPolicyResources $deployedPolicyResources `
    -assignments $assignments `
    -roleAssignments $roleAssignments `
    -allDefinitions $allDefinitions `
    -allAssignments $allAssignments `
    -replaceDefinitions $replaceDefinitions `
    -policyRoleIds $policyRoleIds

$exemptions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfOrphans = 0
    numberOfChanges = 0
    numberUnchanged = 0
}

# Process exemption JSON files
if ($exemptionsAreManaged) {
    Build-ExemptionsPlan `
        -exemptionsRootFolder $exemptionsFolderForPacEnvironment `
        -pacEnvironment $pacEnvironment `
        -allAssignments $allAssignments `
        -assignments $assignments `
        -deployedExemptions $deployedPolicyResources.policyExemptions `
        -exemptions $exemptions
}

$timestamp = Get-Date -AsUTC -Format "u"
$policyPlan = @{
    createdOn            = $timestamp
    pacOwnerId           = $pacOwnerId
    policyDefinitions    = $policyDefinitions
    policySetDefinitions = $policySetDefinitions
    assignments          = $assignments
    exemptions           = $exemptions
}
$rolesPlan = @{
    createdOn       = $timestamp
    pacOwnerId      = $pacOwnerId
    roleAssignments = $roleAssignments
}

Write-Information "==================================================================================================="
Write-Information "Summary"
Write-Information "==================================================================================================="
$policyChanged = $false
$count = $policyDefinitions.numberUnchanged
if ($count -gt 0) {
    Write-Information "Policy definitions     - unchanged : $($count)"
}
$count = $policyDefinitions.new.Count
if ($count -gt 0) {
    Write-Information "Policy definitions     - new       : $($count)"
    $policyChanged = $true
}
$count = $policyDefinitions.update.Count
if ($count -gt 0) {
    Write-Information "Policy definitions     - updated   : $($count)"
    $policyChanged = $true
}
$count = $policyDefinitions.replace.Count
if ($count -gt 0) {
    Write-Information "Policy definitions     - replaced  : $($count)"
    $policyChanged = $true
}
$count = $policyDefinitions.delete.Count
if ($count -gt 0) {
    Write-Information "Policy definitions     - deleted   : $($count)"
    $policyChanged = $true
}
$count = $policySetDefinitions.numberUnchanged
if ($count -gt 0) {
    Write-Information "Policy Set definitions - unchanged : $($count)"
}
$count = $policySetDefinitions.new.Count
if ($count -gt 0) {
    Write-Information "Policy Set definitions - new       : $($count)"
    $policyChanged = $true
}
$count = $policySetDefinitions.update.Count
if ($count -gt 0) {
    Write-Information "Policy Set definitions - updated   : $($count)"
    $policyChanged = $true
}
$count = $policySetDefinitions.replace.Count
if ($count -gt 0) {
    Write-Information "Policy Set definitions - replaced  : $($count)"
    $policyChanged = $true
}
$count = $policySetDefinitions.delete.Count
if ($count -gt 0) {
    Write-Information "Policy Set definitions - deleted   : $($count)"
    $policyChanged = $true
}
$count = $assignments.numberUnchanged
if ($count -gt 0) {
    Write-Information "Policy Assignments     - unchanged : $($count)"
}
$count = $assignments.new.Count
if ($count -gt 0) {
    Write-Information "Policy Assignments     - new       : $($count)"
    $policyChanged = $true
}
$count = $assignments.update.Count
if ($count -gt 0) {
    Write-Information "Policy Assignments     - updated   : $($count)"
    $policyChanged = $true
}
$count = $assignments.replace.Count
if ($count -gt 0) {
    Write-Information "Policy Assignments     - replaced  : $($count)"
    $policyChanged = $true
}
$count = $assignments.delete.Count
if ($count -gt 0) {
    Write-Information "Policy Assignments     - deleted   : $($count)"
    $policyChanged = $true
}

$roleAssignmentsChanged = $false
$count = $roleAssignments.removed.Count
if ($count -gt 0) {
    Write-Information "Role Assignments       - removed   : $($count)"
    $roleAssignmentsChanged = $true
}
$count = $roleAssignments.added.Count
if ($count -gt 0) {
    Write-Information "Role Assignments       - added     : $($count)"
    $roleAssignmentsChanged = $true
}

if ($exemptionsAreManaged) {
    $count = $exemptions.numberUnchanged
    if ($count -gt 0) {
        Write-Information "Policy Exemptions      - unchanged : $($count)"
    }
    $count = $exemptions.new.Count
    if ($count -gt 0) {
        Write-Information "Policy Exemptions      - new       : $($count)"
    }
    $count = $exemptions.update.Count
    if ($count -gt 0) {
        Write-Information "Policy Exemptions      - updated   : $($count)"
    }
    $count = $exemptions.replace.Count
    if ($count -gt 0) {
        Write-Information "Policy Exemptions      - replaced  : $($count)"
    }
    $count = $exemptions.delete.Count
    if ($count -gt 0) {
        Write-Information "Policy Exemptions      - deleted   : $($count)"
    }
    $count = $exemptions.numberOfOrphans
    if ($count -gt 0) {
        Write-Information "Policy Exemptions      - orphaned  : $($count)"
    }
}

Write-Information ""
$policyStage = "no"
$planFile = $pacEnvironment.policyPlanOutputFile
if (-not (Test-Path $planFile)) {
    $null = (New-Item $planFile -Force)
}
if ($policyChanged) {
    Write-Information "Policy deployment required; writing Policy plan file '$planFile'"
    $null = $policyPlan | ConvertTo-Json -Depth 100 | Out-File -FilePath $planFile -Force
    $policyStage = "yes"
}
else {
    if (Test-Path $planFile) {
        $null = (Remove-Item $planFile)
    }
    Write-Information "Skipping Policy deployment stage/step - no changes"
}

$roleStage = "no"
$planFile = $pacEnvironment.rolesPlanOutputFile
if (-not (Test-Path $planFile)) {
    $null = (New-Item $planFile -Force)
}
if ($roleAssignmentsChanged) {
    Write-Information "Role assignment changes required; writing Policy plan file '$planFile'"
    $null = $rolesPlan | ConvertTo-Json -Depth 100 | Out-File -FilePath $planFile -Force
    $roleStage = "yes"
}
else {
    if (Test-Path $planFile) {
        $null = (Remove-Item $planFile)
    }
    Write-Information "Skipping Role Assignment stage/step - no changes"
}
Write-Information ""

switch ($devOpsType) {
    ado {
        Write-Host "##vso[task.setvariable variable=deployPolicyChanges;isOutput=true]$($policyStage)"
        Write-Host "##vso[task.setvariable variable=deployRoleChanges;isOutput=true]$($roleStage)"
        break
    }
    default {}
}
