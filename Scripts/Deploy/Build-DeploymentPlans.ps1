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
    [ValidateSet("ado", "gitlab", "")]
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
. "$PSScriptRoot/../Helpers/Get-ParameterNameFromValueString.ps1"
. "$PSScriptRoot/../Helpers/Get-PolicyResourceProperties.ps1"

. "$PSScriptRoot/../Helpers/Remove-EmptyFields.ps1"

. "$PSScriptRoot/../Helpers/Search-AzGraphAllItems.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"
. "$PSScriptRoot/../Helpers/Split-AzPolicyResourceId.ps1"
. "$PSScriptRoot/../Helpers/Split-ScopeId.ps1"

# Initialize
$InformationPreference = "Continue"

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

# Process Policies
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

# Process Policy Sets
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

Write-Information "Policy counts:"
Write-Information "    $($policyDefinitions.numberUnchanged) unchanged"
if ($policyDefinitions.numberOfChanges -eq 0) {
    Write-Information "    $($policyDefinitions.numberOfChanges) changes"
}
else {
    Write-Information "    $($policyDefinitions.numberOfChanges) changes:"
    Write-Information "        new     = $($policyDefinitions.new.Count)"
    Write-Information "        update  = $($policyDefinitions.update.Count)"
    Write-Information "        replace = $($policyDefinitions.replace.Count)"
    Write-Information "        delete  = $($policyDefinitions.delete.Count)"
}

Write-Information "Policy Set counts:"
Write-Information "    $($policySetDefinitions.numberUnchanged) unchanged"
if ($policySetDefinitions.numberOfChanges -eq 0) {
    Write-Information "    $($policySetDefinitions.numberOfChanges) changes"
}
else {
    Write-Information "    $($policySetDefinitions.numberOfChanges) changes:"
    Write-Information "        new     = $($policySetDefinitions.new.Count)"
    Write-Information "        update  = $($policySetDefinitions.update.Count)"
    Write-Information "        replace = $($policySetDefinitions.replace.Count)"
    Write-Information "        delete  = $($policySetDefinitions.delete.Count)"
}

Write-Information "Policy Assignment counts:"
Write-Information "    $($assignments.numberUnchanged) unchanged"
if ($assignments.numberOfChanges -eq 0) {
    Write-Information "    $($assignments.numberOfChanges) changes"
}
else {
    Write-Information "    $($assignments.numberOfChanges) changes:"
    Write-Information "        new     = $($assignments.new.Count)"
    Write-Information "        update  = $($assignments.update.Count)"
    Write-Information "        replace = $($assignments.replace.Count)"
    Write-Information "        delete  = $($assignments.delete.Count)"
}

if ($exemptionsAreManaged) {
    Write-Information "Policy Exemption counts:"
    Write-Information "    $($exemptions.numberUnchanged) unchanged"
    if ($exemptions.numberOfChanges -eq 0) {
        Write-Information "    $($exemptions.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($exemptions.numberOfChanges) changes:"
        Write-Information "        new     = $($exemptions.new.Count)"
        Write-Information "        update  = $($exemptions.update.Count)"
        Write-Information "        replace = $($exemptions.replace.Count)"
        Write-Information "        delete  = $($exemptions.delete.Count)"
        Write-Information "        orphans = $($exemptions.numberOfOrphans)"
    }
}

Write-Information "Role Assignment counts:"
if ($roleAssignments.numberOfChanges -eq 0) {
    Write-Information "    $($roleAssignments.numberOfChanges) changes"
}
else {
    Write-Information "    $($roleAssignments.numberOfChanges) changes:"
    Write-Information "        add     = $($roleAssignments.added.Count)"
    Write-Information "        remove  = $($roleAssignments.removed.Count)"
}

Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Output plan(s)"
$policyResourceChanges = $policyDefinitions.numberOfChanges
$policyResourceChanges += $policySetDefinitions.numberOfChanges
$policyResourceChanges += $assignments.numberOfChanges
$policyResourceChanges += $exemptions.numberOfChanges

$policyStage = "no"
$planFile = $pacEnvironment.policyPlanOutputFile
if ($policyResourceChanges -gt 0) {
    Write-Information "   Policy resource deployment required; writing Policy plan file '$planFile'"
    if (-not (Test-Path $planFile)) {
        $null = (New-Item $planFile -Force)
    }
    $null = $policyPlan | ConvertTo-Json -Depth 100 | Out-File -FilePath $planFile -Force
    $policyStage = "yes"
}
else {
    if (Test-Path $planFile) {
        $null = (Remove-Item $planFile)
    }
    Write-Information "    Skipping Policy deployment stage/step - no changes"
}

$roleStage = "no"
$planFile = $pacEnvironment.rolesPlanOutputFile
if ($roleAssignments.numberOfChanges -gt 0) {
    Write-Information "    Role assignment changes required; writing Policy plan file '$planFile'"
    if (-not (Test-Path $planFile)) {
        $null = (New-Item $planFile -Force)
    }
    $null = $rolesPlan | ConvertTo-Json -Depth 100 | Out-File -FilePath $planFile -Force
    $roleStage = "yes"
}
else {
    if (Test-Path $planFile) {
        $null = (Remove-Item $planFile)
    }
    Write-Information "    Skipping Role Assignment stage/step - no changes"
}
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information ""

switch ($devOpsType) {
    ado {
        Write-Host "##vso[task.setvariable variable=deployPolicyChanges;isOutput=true]$($policyStage)"
        Write-Host "##vso[task.setvariable variable=deployRoleChanges;isOutput=true]$($roleStage)"
        break
    }
    gitlab {
        Add-Content "build.env" "deployPolicyChanges=$($policyStage)"
        Add-Content "build.env" "deployRoleChanges=$($roleStage)"
    }
    default {}
}
