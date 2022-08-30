#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "When using this switch, the script includes resource groups for assignment calculations. Warning: this is time-consuming.")]
    [switch]$IncludeResourceGroupsForAssignments,

    [Parameter(Mandatory = $false, HelpMessage = "When using this switch, the script will NOT delete extraneous Policy definitions, Initiative definitions and Assignments.")]
    [switch]$SuppressDeletes,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output folder path for plan files. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$OutpuFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Plan output filename. Defaults to `$OutputFolder/policy-plan-`$PacEnvironmentSelector/policy-plan.json.")]
    [string]$PlanFile,

    [Parameter(Mandatory = $false, HelpMessage = "Use switch to indicate interactive use")] [switch] $interactive
)

# Load cmdlets
. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Build-AzInitiativeDefinitionsPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyAssignmentIdentityAndRoleChanges.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyAssignmentsPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyExemptionsPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyDefinitionsForInitiative.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyDefinitionsPlan.ps1"
. "$PSScriptRoot/../Helpers/Confirm-AssignmentParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-InitiativeDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-MetadataMatches.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionsUsedMatch.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AssignmentDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Helpers/Get-NotScope.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ObjectValueEqualityDeep.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-DeepClone.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"
. "$PSScriptRoot/../Helpers/Write-AssignmentDetails.ps1"

# Initialize
$InformationPreference = "Continue"
Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive.IsPresent
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive

# Process resulting values
$rootScope = $pacEnvironment.rootScope
$rootScopeId = $pacEnvironment.rootScopeId
if ($PlanFile -eq "") {
    $PlanFile = $pacEnvironment.policyPlanOutputFile
}

# Getting existing Policy Assignmentscls
$existingAssignments = $null
$scopeTreeInfo = Get-AzScopeTree `
    -tenantId $pacEnvironment.tenantId `
    -scopeParam $rootScope `
    -defaultSubscriptionId $pacEnvironment.defaultSubscriptionId

$existingAssignments, $null, $existingExemptions = Get-AzAssignmentsAtScopeRecursive `
    -scopeTreeInfo $scopeTreeInfo `
    -notScopeIn $pacEnvironment.globalNotScopeList `
    -includeResourceGroups $IncludeResourceGroupsForAssignments.IsPresent

# Getting existing Policy/Initiative definitions and Policy Assignments in the chosen scope of Azure
$allAzPolicyInitiativeDefinitions = Get-AzPolicyInitiativeDefinitions -rootScope $rootScope -rootScopeId $rootScopeId

# Collections for roleDefinitionIds
[hashtable] $policyNeededRoleDefinitionIds = @{}
[hashtable] $initiativeNeededRoleDefinitionIds = @{}

# Process Policy definitions
$newPolicyDefinitions = @{}
$updatedPolicyDefinitions = @{}
$replacedPolicyDefinitions = @{}
$deletedPolicyDefinitions = @{}
$unchangedPolicyDefinitions = @{}
$allPolicyDefinitions = ($allAzPolicyInitiativeDefinitions.builtInPolicyDefinitions).Clone()
$customPolicyDefinitions = @{}
Build-AzPolicyDefinitionsPlan `
    -policyDefinitionsRootFolder $pacEnvironment.policyDefinitionsFolder `
    -noDelete $SuppressDeletes.IsPresent `
    -rootScope $rootScope `
    -existingCustomPolicyDefinitions $allAzPolicyInitiativeDefinitions.existingCustomPolicyDefinitions `
    -builtInPolicyDefinitions $allAzPolicyInitiativeDefinitions.builtInPolicyDefinitions `
    -allPolicyDefinitions $allPolicyDefinitions `
    -newPolicyDefinitions $newPolicyDefinitions `
    -updatedPolicyDefinitions $updatedPolicyDefinitions `
    -replacedPolicyDefinitions $replacedPolicyDefinitions `
    -deletedPolicyDefinitions $deletedPolicyDefinitions `
    -unchangedPolicyDefinitions $unchangedPolicyDefinitions `
    -customPolicyDefinitions $customPolicyDefinitions `
    -policyNeededRoleDefinitionIds $policyNeededRoleDefinitionIds

# Process Initiative definitions
$newInitiativeDefinitions = @{}
$updatedInitiativeDefinitions = @{}
$replacedInitiativeDefinitions = @{}
$deletedInitiativeDefinitions = @{}
$unchangedInitiativeDefinitions = @{}
$allInitiativeDefinitions = ($allAzPolicyInitiativeDefinitions.builtInInitiativeDefinitions).Clone()
$customInitiativeDefinitions = @{}
Build-AzInitiativeDefinitionsPlan `
    -initiativeDefinitionsRootFolder $pacEnvironment.initiativeDefinitionsFolder `
    -noDelete $SuppressDeletes.IsPresent `
    -rootScope $rootScope `
    -rootScopeId $rootScopeId `
    -existingCustomInitiativeDefinitions $allAzPolicyInitiativeDefinitions.existingCustomInitiativeDefinitions `
    -builtInInitiativeDefinitions $allAzPolicyInitiativeDefinitions.builtInInitiativeDefinitions `
    -allPolicyDefinitions $allPolicyDefinitions `
    -allInitiativeDefinitions $allInitiativeDefinitions `
    -newInitiativeDefinitions $newInitiativeDefinitions `
    -updatedInitiativeDefinitions $updatedInitiativeDefinitions `
    -replacedInitiativeDefinitions $replacedInitiativeDefinitions `
    -deletedInitiativeDefinitions $deletedInitiativeDefinitions `
    -unchangedInitiativeDefinitions $unchangedInitiativeDefinitions `
    -customInitiativeDefinitions $customInitiativeDefinitions `
    -policyNeededRoleDefinitionIds $policyNeededRoleDefinitionIds `
    -initiativeNeededRoleDefinitionIds $initiativeNeededRoleDefinitionIds

# Process Assignment JSON files
$allAssignments = @{}
$newAssignments = @{}
$updatedAssignments = @{}
$replacedAssignments = @{}
$deletedAssignments = @{}
$unchangedAssignments = @{}
$removedRoleAssignments = @{}
$addedRoleAssignments = @{}
Build-AzPolicyAssignmentsPlan `
    -pacEnvironmentSelector $pacEnvironment.pacEnvironmentSelector `
    -assignmentsRootFolder $pacEnvironment.assignmentsFolder `
    -noDelete $SuppressDeletes.IsPresent `
    -rootScope $rootScope `
    -rootScopeId $rootScopeId `
    -scopeTreeInfo $scopeTreeInfo `
    -globalNotScopeList $pacEnvironment.globalNotScopeList `
    -managedIdentityLocation $pacEnvironment.managedIdentityLocation `
    -allPolicyDefinitions $allPolicyDefinitions `
    -customPolicyDefinitions $customPolicyDefinitions `
    -replacedPolicyDefinitions $replacedPolicyDefinitions `
    -allInitiativeDefinitions $allInitiativeDefinitions `
    -customInitiativeDefinitions $customInitiativeDefinitions `
    -replacedInitiativeDefinitions $replacedInitiativeDefinitions `
    -policyNeededRoleDefinitionIds $policyNeededRoleDefinitionIds `
    -initiativeNeededRoleDefinitionIds $initiativeNeededRoleDefinitionIds `
    -allAssignments $allAssignments `
    -existingAssignments $existingAssignments `
    -newAssignments $newAssignments `
    -updatedAssignments $updatedAssignments `
    -replacedAssignments $replacedAssignments `
    -deletedAssignments $deletedAssignments `
    -unchangedAssignments $unchangedAssignments `
    -removedRoleAssignments $removedRoleAssignments `
    -addedRoleAssignments $addedRoleAssignments

# Process exemption JSON files
[hashtable] $newExemptions = @{}
[hashtable] $updatedExemptions = @{}
[hashtable] $replacedExemptions = @{}
[hashtable] $deletedExemptions = @{}
[hashtable] $unchangedExemptions = @{}
[hashtable] $orphanedExemptions = @{}
[hashtable] $expiredExemptions = @{}
Build-AzPolicyExemptionsPlan `
    -pacEnvironmentSelector $pacEnvironment.pacEnvironmentSelector `
    -exemptionsRootFolder $pacEnvironment.exemptionsFolder `
    -noDelete $SuppressDeletes.IsPresent `
    -allAssignments $allAssignments `
    -replacedAssignments $replacedAssignments `
    -existingExemptions $existingExemptions `
    -newExemptions $newExemptions `
    -updatedExemptions $updatedExemptions `
    -replacedExemptions $replacedExemptions `
    -deletedExemptions $deletedExemptions `
    -unchangedExemptions $unchangedExemptions `
    -orphanedExemptions $orphanedExemptions `
    -expiredExemptions $expiredExemptions

# Publish plan to be consumed by next stage
$numberOfPolicyChanges = `
    $deletedPolicyDefinitions.Count + `
    $replacedPolicyDefinitions.Count + `
    $updatedPolicyDefinitions.Count + `
    $newPolicyDefinitions.Count + `
    $deletedInitiativeDefinitions.Count + `
    $replacedInitiativeDefinitions.Count + `
    $updatedInitiativeDefinitions.Count + `
    $newInitiativeDefinitions.Count + `
    $deletedAssignments.Count + `
    $replacedAssignments.Count + `
    $updatedAssignments.Count + `
    $newAssignments.Count + `
    $newExemptions.Count + `
    $updatedExemptions.Count + `
    $replacedExemptions.Count + `
    $deletedExemptions.Count
$numberOfRoleChanges = `
    $removedRoleAssignments.Count + `
    $addedRoleAssignments.Count
$noChanges = $numberOfPolicyChanges -eq 0 -and $numberOfRoleChanges -eq 0

$plan = @{
    rootScope                     = $rootScope
    rootScopeId                   = $rootScopeId
    tenantID                      = $TenantId
    noChanges                     = $noChanges
    createdOn                     = (Get-Date -AsUTC -Format "u")

    deletedPolicyDefinitions      = $deletedPolicyDefinitions
    replacedPolicyDefinitions     = $replacedPolicyDefinitions
    updatedPolicyDefinitions      = $updatedPolicyDefinitions
    newPolicyDefinitions          = $newPolicyDefinitions

    deletedInitiativeDefinitions  = $deletedInitiativeDefinitions
    replacedInitiativeDefinitions = $replacedInitiativeDefinitions
    updatedInitiativeDefinitions  = $updatedInitiativeDefinitions
    newInitiativeDefinitions      = $newInitiativeDefinitions

    deletedAssignments            = $deletedAssignments
    replacedAssignments           = $replacedAssignments
    updatedAssignments            = $updatedAssignments
    newAssignments                = $newAssignments

    deletedExemptions             = $deletedExemptions
    replacedExemptions            = $replacedExemptions
    updatedExemptions             = $updatedExemptions
    newExemptions                 = $newExemptions
    orphanedExemptions            = $orphanedExemptions
    expiredExemptions             = $expiredExemptions

    removedRoleAssignments        = $removedRoleAssignments
    addedRoleAssignments          = $addedRoleAssignments
}

Write-Information "==================================================================================================="
# Retrieve the plan file from the environment
Write-Information "Writing plan file $PlanFile"
if (-not (Test-Path $PlanFile)) {
    $null = New-Item $PlanFile -Force
}
$null = $plan | ConvertTo-Json -Depth 100 | Out-File -FilePath $PlanFile -Force
Write-Information "==================================================================================================="
Write-Information ""
Write-Information ""

Write-Information "==================================================================================================="
Write-Information "Summary"
Write-Information "==================================================================================================="
Write-Information "rootScope   : $($rootScopeId)"
Write-Information "tenantID    : $($TenantID)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Policy definitions - unchanged : $($unchangedPolicyDefinitions.Count)"
Write-Information "Policy definitions - new       : $($newPolicyDefinitions.Count)"
Write-Information "Policy definitions - updated   : $($updatedPolicyDefinitions.Count)"
Write-Information "Policy definitions - replaced  : $($replacedPolicyDefinitions.Count)"
Write-Information "Policy definitions - deleted   : $($deletedPolicyDefinitions.Count)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Initiative definitions - unchanged : $($unchangedInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - new       : $($newInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - updated   : $($updatedInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - replaced  : $($replacedInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - deleted   : $($deletedInitiativeDefinitions.Count)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Assignments - unchanged : $($unchangedAssignments.Count)"
Write-Information "Assignments - new       : $($newAssignments.Count)"
Write-Information "Assignments - updated   : $($updatedAssignments.Count)"
Write-Information "Assignments - replaced  : $($replacedAssignments.Count)"
Write-Information "Assignments - deleted   : $($deletedAssignments.Count)"
Write-Information "Assignments - Removed Role Assignment(s) : $($removedRoleAssignments.Count)"
Write-Information "Assignments - New Role Assignment(s)     : $($addedRoleAssignments.Count)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Exemptions - unchanged : $($unchangedExemptions.Count)"
Write-Information "Exemptions - new       : $($newExemptions.Count)"
Write-Information "Exemptions - updated   : $($updatedExemptions.Count)"
Write-Information "Exemptions - replaced  : $($replacedExemptions.Count)"
Write-Information "Exemptions - deleted   : $($deletedExemptions.Count)"
Write-Information "Exemptions - orphaned in definition file : $($orphanedExemptions.Count)"
Write-Information "Exemptions - expired in definition file  : $($expiredExemptions.Count)"

Write-Information "***************************************************************************************************"
if ($numberOfRoleChanges -gt 0) {
    Write-Host "##vso[task.setvariable variable=deployPolicyChanges;isOutput=true]yes"
    Write-Host "##vso[task.setvariable variable=deployRoleChanges;isOutput=true]yes"
    Write-Information "Executing Policy deployment stage/step"
    Write-Information "Executing Role Assignment stage/step"
}
elseif ($numberOfPolicyChanges -gt 0) {
    Write-Host "##vso[task.setvariable variable=deployPolicyChanges;isOutput=true]yes"
    Write-Host "##vso[task.setvariable variable=deployRoleChanges;isOutput=true]no"
    Write-Information "Executing Policy deployment stage/step"
    Write-Information "Skipping Role Assignment stage/step - no changes"
}
else {
    Write-Host "##vso[task.setvariable variable=deployPolicyChanges;isOutput=true]no"
    Write-Host "##vso[task.setvariable variable=deployRoleChanges;isOutput=true]no"
    Write-Information "Skipping Policy deployment stage/step - no changes"
    Write-Information "Skipping Role Assignment stage/step - no changes"
}
