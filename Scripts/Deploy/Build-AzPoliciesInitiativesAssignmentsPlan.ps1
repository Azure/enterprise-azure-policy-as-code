#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a vlaue. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "When using this switch, the script includes resource groups for assignment calculations. Warning: this is time-consuming.")]
    [switch]$IncludeResourceGroupsForAssignments,

    [Parameter(Mandatory = $false, HelpMessage = "When using this switch, the script will NOT delete extraneous Policy definitions, Initiative definitions and Assignments.")]
    [switch]$SuppressDeletes,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable PacDefinitionsRootFolder or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Plan output filename. If empty it is read from `$GlobalSettingsFile.")]
    [string]$PlanFile = ""

)

function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $printHeader,
        $def,
        $policySpecText,
        $scopeInfo,
        $roleDefinitions,
        $prefix
    )

    if ($printHeader) {
        Write-Information "    Assignment `'$($def.assignment.DisplayName)`' ($($def.assignment.Name))"
        Write-Information "                Description: $($def.assignment.Description)"
        Write-Information "                $($policySpecText)"
    }
    Write-Information "        $($prefix) at $($scopeInfo.scope)"
    # if ($roleDefinitions.Length -gt 0) {
    #     foreach ($roleDefinition in $roleDefinitions) {
    #         Write-Information "                RoleId=$($roleDefinition.roleDefinitionId), Scope=$($roleDefinition.scope)"
    #     }
    # }
}

# Load cmdlets
. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"
. "$PSScriptRoot/../Helpers/Build-AzInitiativeDefinitionsPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyAssignmentIdentityAndRoleChanges.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyAssignmentsPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyDefinitionsForInitiative.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyDefinitionsPlan.ps1"
. "$PSScriptRoot/../Helpers/Confirm-AssignmentParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-InitiativeDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-MetadataMatches.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionsUsedMatch.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AssignmentDefs.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyNotScope.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
# . "$PSScriptRoot/../Helpers/Merge-Initiatives.ps1"
. "$PSScriptRoot/../Utils/Confirm-ObjectValueEqualityDeep.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Utils/Get-DeepClone.ps1"
. "$PSScriptRoot/../Utils/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"

# Initialize
$InformationPreference = "Continue"
Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput
$environment = Initialize-Environment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder
$rootScope = $environment.rootScope
$rootScopeId = $environment.rootScopeId
if ($PlanFile -eq "") {
    $PlanFile = $environment.planFile
}

# Getting existing Policy Assignments
$existingAssignments = $null
$scopeTreeInfo = Get-AzScopeTree `
    -tenantId $environment.tenantId `
    -scopeParam $rootScope `
    -defaultSubscriptionId $environment.defaultSubscriptionId

$existingAssignments, $null = Get-AzAssignmentsAtScopeRecursive `
    -scopeTreeInfo $scopeTreeInfo `
    -notScopeIn $environment.globalNotScopeList `
    -includeResourceGroups $IncludeResourceGroupsForAssignments.IsPresent

# Getting existing Policy/Initiative definitions and Policy Assignments in the chosen scope of Azure
$collections = Get-AllAzPolicyInitiativeDefinitions -rootScopeId $rootScopeId

# Process Policy definitions
$newPolicyDefinitions = @{}
$updatedPolicyDefinitions = @{}
$replacedPolicyDefinitions = @{}
$deletedPolicyDefinitions = @{}
$unchangedPolicyDefinitions = @{}
$allPolicyDefinitions = ($collections.builtInPolicyDefinitions).Clone()
$customPolicyDefinitions = @{}
Build-AzPolicyDefinitionsPlan `
    -policyDefinitionsRootFolder $environment.policyDefinitionsFolder `
    -noDelete $SuppressDeletes.IsPresent `
    -rootScope $rootScope `
    -existingCustomPolicyDefinitions $collections.existingCustomPolicyDefinitions `
    -builtInPolicyDefinitions $collections.builtInPolicyDefinitions `
    -allPolicyDefinitions $allPolicyDefinitions `
    -newPolicyDefinitions $newPolicyDefinitions `
    -updatedPolicyDefinitions $updatedPolicyDefinitions `
    -replacedPolicyDefinitions $replacedPolicyDefinitions `
    -deletedPolicyDefinitions $deletedPolicyDefinitions `
    -unchangedPolicyDefinitions $unchangedPolicyDefinitions `
    -customPolicyDefinitions $customPolicyDefinitions

# Process Initiative definitions
$newInitiativeDefinitions = @{}
$updatedInitiativeDefinitions = @{}
$replacedInitiativeDefinitions = @{}
$deletedInitiativeDefinitions = @{}
$unchangedInitiativeDefinitions = @{}
$allInitiativeDefinitions = ($collections.builtInInitiativeDefinitions).Clone()
$customInitiativeDefinitions = @{}
Build-AzInitiativeDefinitionsPlan `
    -initiativeDefinitionsRootFolder $environment.initiativeDefinitionsFolder `
    -noDelete $SuppressDeletes.IsPresent `
    -rootScope $rootScope `
    -rootScopeId $rootScopeId `
    -existingCustomInitiativeDefinitions $collections.existingCustomInitiativeDefinitions `
    -builtInInitiativeDefinitions $collections.builtInInitiativeDefinitions `
    -allPolicyDefinitions $allPolicyDefinitions `
    -allInitiativeDefinitions $allInitiativeDefinitions `
    -newInitiativeDefinitions $newInitiativeDefinitions `
    -updatedInitiativeDefinitions $updatedInitiativeDefinitions `
    -replacedInitiativeDefinitions $replacedInitiativeDefinitions `
    -deletedInitiativeDefinitions $deletedInitiativeDefinitions `
    -unchangedInitiativeDefinitions $unchangedInitiativeDefinitions `
    -customInitiativeDefinitions $customInitiativeDefinitions

# Process Assignment JSON files
$newAssignments = @{}
$updatedAssignments = @{}
$replacedAssignments = @{}
$deletedAssignments = @{}
$unchangedAssignments = @{}
$removedRoleAssignments = @{}
$addedRoleAssignments = @{}
if (!$TestInitiativeMerge.IsPresent) {
    Build-AzPolicyAssignmentsPlan `
        -pacEnvironmentSelector $environment.pacEnvironmentSelector `
        -assignmentsRootFolder $environment.assignmentsFolder `
        -noDelete $SuppressDeletes.IsPresent `
        -rootScope $rootScope `
        -rootScopeId $rootScopeId `
        -scopeTreeInfo $scopeTreeInfo `
        -globalNotScopeList $environment.globalNotScopeList `
        -managedIdentityLocation $environment.managedIdentityLocation `
        -allPolicyDefinitions $allPolicyDefinitions `
        -customPolicyDefinitions $customPolicyDefinitions `
        -replacedPolicyDefinitions $replacedPolicyDefinitions `
        -allInitiativeDefinitions $allInitiativeDefinitions `
        -customInitiativeDefinitions $customInitiativeDefinitions `
        -replacedInitiativeDefinitions $replacedInitiativeDefinitions `
        -existingAssignments $existingAssignments `
        -newAssignments $newAssignments `
        -updatedAssignments $updatedAssignments `
        -replacedAssignments $replacedAssignments `
        -deletedAssignments $deletedAssignments `
        -unchangedAssignments $unchangedAssignments `
        -removedRoleAssignments $removedRoleAssignments `
        -addedRoleAssignments $addedRoleAssignments
}

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
    $newAssignments.Count
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
if (!$TestInitiativeMerge.IsPresent) {
    Write-Information "Assignments - unchanged : $($unchangedAssignments.Count)"
    Write-Information "Assignments - new       : $($newAssignments.Count)"
    Write-Information "Assignments - updated   : $($updatedAssignments.Count)"
    Write-Information "Assignments - replaced  : $($replacedAssignments.Count)"
    Write-Information "Assignments - deleted   : $($deletedAssignments.Count)"
    Write-Information "---------------------------------------------------------------------------------------------------"
    Write-Information "Assignments - Removed Role Assignment(s) : $($removedRoleAssignments.Count)"
    Write-Information "Assignments - New Role Assignment(s)     : $($addedRoleAssignments.Count)"

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
}
