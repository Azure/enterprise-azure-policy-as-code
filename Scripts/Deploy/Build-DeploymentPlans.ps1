#Requires -PSEdition Core

<#
.SYNOPSIS
    Builds the deployment plans for the Policy as Code (PAC) environment.

.PARAMETER PacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFolder
    Output folder path for plan files. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Output'.

.PARAMETER Interactive
    Script is used interactively. Script can prompt the interactive user for input.

.PARAMETER DevOpsType
    If set, outputs variables consumable by conditions in a DevOps pipeline. Valid values are '', 'ado' and 'gitlab'.

.EXAMPLE
    .\Build-DeploymentPlans.ps1 -PacEnvironmentSelector "dev"

    Builds the deployment plans for the Policy as Code (PAC) environment 'dev'.

.EXAMPLE
    .\Build-DeploymentPlans.ps1 -PacEnvironmentSelector "dev" -DevOpsType "ado"

    Builds the deployment plans for the Policy as Code (PAC) environment 'dev' and outputs variables consumable by conditions in an Azure DevOps pipeline.

.LINK
    https://azure.github.io/enterprise-azure-Policy-as-code/#deployment-scripts

#>

[CmdletBinding()]
param (
    [parameter(HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(HelpMessage = "Output folder path for plan files. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$OutputFolder,

    [Parameter(HelpMessage = "Script is used interactively. Script can prompt the interactive user for input.")]
    [switch] $Interactive,

    [Parameter(HelpMessage = "If set, outputs variables consumable by conditions in a DevOps pipeline.")]
    [ValidateSet("ado", "gitlab", "")]
    [string] $DevOpsType = ""
)

$PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
}

Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# Initialize
$InformationPreference = "Continue"

$PacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
Set-AzCloudTenantSubscription -Cloud $PacEnvironment.cloud -TenantId $PacEnvironment.tenantId -Interactive $PacEnvironment.interactive

# Getting existing Policy resources
$ExemptionsAreNotManagedMessage = ""
$PolicyExemptionsFolder = $PacEnvironment.policyExemptionsFolder
$ExemptionsFolderForPacEnvironment = "$($PolicyExemptionsFolder)/$($PacEnvironment.pacSelector)"
if (!(Test-Path $PolicyExemptionsFolder -PathType Container)) {
    $ExemptionsAreNotManagedMessage = "Policy Exemptions folder 'policyExemptions' not found. Exemptions not managed by this EPAC instance."
}
elseif (!(Test-Path $ExemptionsFolderForPacEnvironment -PathType Container)) {
    $ExemptionsAreNotManagedMessage = "Policy Exemptions are not managed by this EPAC instance's PaC environment $($PacEnvironment.pacSelector)!"
}
$ExemptionsAreNotManaged = $ExemptionsAreNotManagedMessage -eq ""

$ScopeTable = Get-AzScopeTree -PacEnvironment $PacEnvironment
$DeployedPolicyResources = Get-AzPolicyResources -PacEnvironment $PacEnvironment -ScopeTable $ScopeTable -SkipExemptions:$ExemptionsAreNotManaged

# Process Policies
$PolicyDefinitions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfChanges = 0
    numberUnchanged = 0
}
$PolicyRoleIds = @{}
$AllDefinitions = @{
    policydefinitions    = @{}
    policysetdefinitions = @{}
}
$ReplaceDefinitions = @{}

Build-PolicyPlan `
    -DefinitionsRootFolder $PacEnvironment.policyDefinitionsFolder `
    -PacEnvironment $PacEnvironment `
    -DeployedDefinitions $DeployedPolicyResources.policydefinitions `
    -Definitions $PolicyDefinitions `
    -AllDefinitions $AllDefinitions `
    -ReplaceDefinitions $ReplaceDefinitions `
    -PolicyRoleIds $PolicyRoleIds

# Process Policy Sets
$PolicySetDefinitions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfChanges = 0
    numberUnchanged = 0
}

Build-PolicySetPlan `
    -DefinitionsRootFolder $PacEnvironment.policySetDefinitionsFolder `
    -PacEnvironment $PacEnvironment `
    -DeployedDefinitions $DeployedPolicyResources.policysetdefinitions `
    -Definitions $PolicySetDefinitions `
    -AllDefinitions $AllDefinitions `
    -ReplaceDefinitions $ReplaceDefinitions `
    -PolicyRoleIds $PolicyRoleIds

# Process Assignment JSON files
$Assignments = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfChanges = 0
    numberUnchanged = 0
}
$RoleAssignments = @{
    numberOfChanges = 0
    added           = @()
    removed         = @()
}
$AllAssignments = @{}

Build-AssignmentPlan `
    -AssignmentsRootFolder $PacEnvironment.policyAssignmentsFolder `
    -PacEnvironment $PacEnvironment `
    -ScopeTable $ScopeTable `
    -DeployedPolicyResources $DeployedPolicyResources `
    -Assignments $Assignments `
    -RoleAssignments $RoleAssignments `
    -AllDefinitions $AllDefinitions `
    -AllAssignments $AllAssignments `
    -ReplaceDefinitions $ReplaceDefinitions `
    -PolicyRoleIds $PolicyRoleIds

$Exemptions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfOrphans = 0
    numberOfChanges = 0
    numberUnchanged = 0
}

# Process exemption JSON files
Build-ExemptionsPlan `
    -ExemptionsRootFolder $ExemptionsFolderForPacEnvironment `
    -ExemptionsAreNotManagedMessage $ExemptionsAreNotManagedMessage `
    -PacEnvironment $PacEnvironment `
    -AllAssignments $AllAssignments `
    -Assignments $Assignments `
    -DeployedExemptions $DeployedPolicyResources.policyExemptions `
    -Exemptions $Exemptions

# Output Plan
$PacOwnerId = $PacEnvironment.pacOwnerId
$timestamp = Get-Date -AsUTC -Format "u"
$PolicyPlan = @{
    createdOn            = $timestamp
    pacOwnerId           = $PacOwnerId
    policyDefinitions    = $PolicyDefinitions
    policySetDefinitions = $PolicySetDefinitions
    assignments          = $Assignments
    exemptions           = $Exemptions
}
$rolesPlan = @{
    createdOn       = $timestamp
    pacOwnerId      = $PacOwnerId
    roleAssignments = $RoleAssignments
}

Write-Information "==================================================================================================="
Write-Information "Summary"
Write-Information "==================================================================================================="

if ($null -ne $PacEnvironment.policyDefinitionsFolder) {
    Write-Information "Policy counts:"
    Write-Information "    $($PolicyDefinitions.numberUnchanged) unchanged"
    if ($PolicyDefinitions.numberOfChanges -eq 0) {
        Write-Information "    $($PolicyDefinitions.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($PolicyDefinitions.numberOfChanges) changes:"
        Write-Information "        new     = $($PolicyDefinitions.new.psbase.Count)"
        Write-Information "        update  = $($PolicyDefinitions.update.psbase.Count)"
        Write-Information "        replace = $($PolicyDefinitions.replace.psbase.Count)"
        Write-Information "        delete  = $($PolicyDefinitions.delete.psbase.Count)"
    }
}
else {
    Write-Information "Policy definitions not managed by EPAC."
}

if ($null -ne $PacEnvironment.policySetDefinitionsFolder) {
    Write-Information "Policy Set counts:"
    Write-Information "    $($PolicySetDefinitions.numberUnchanged) unchanged"
    if ($PolicySetDefinitions.numberOfChanges -eq 0) {
        Write-Information "    $($PolicySetDefinitions.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($PolicySetDefinitions.numberOfChanges) changes:"
        Write-Information "        new     = $($PolicySetDefinitions.new.psbase.Count)"
        Write-Information "        update  = $($PolicySetDefinitions.update.psbase.Count)"
        Write-Information "        replace = $($PolicySetDefinitions.replace.psbase.Count)"
        Write-Information "        delete  = $($PolicySetDefinitions.delete.psbase.Count)"
    }
}
else {
    Write-Information "Policy Set definitions not managed by EPAC."
}

if ($null -ne $PacEnvironment.policyAssignmentsFolder) {
    Write-Information "Policy Assignment counts:"
    Write-Information "    $($Assignments.numberUnchanged) unchanged"
    if ($Assignments.numberOfChanges -eq 0) {
        Write-Information "    $($Assignments.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($Assignments.numberOfChanges) changes:"
        Write-Information "        new     = $($Assignments.new.psbase.Count)"
        Write-Information "        update  = $($Assignments.update.psbase.Count)"
        Write-Information "        replace = $($Assignments.replace.psbase.Count)"
        Write-Information "        delete  = $($Assignments.delete.psbase.Count)"
    }
}
else {
    Write-Information "Policy definitions not managed by EPAC."
}

if ($ExemptionsAreManaged) {
    Write-Information "Policy Exemption counts:"
    Write-Information "    $($Exemptions.numberUnchanged) unchanged"
    if ($Exemptions.numberOfChanges -eq 0) {
        Write-Information "    $($Exemptions.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($Exemptions.numberOfChanges) changes:"
        Write-Information "        new     = $($Exemptions.new.psbase.Count)"
        Write-Information "        update  = $($Exemptions.update.psbase.Count)"
        Write-Information "        replace = $($Exemptions.replace.psbase.Count)"
        Write-Information "        delete  = $($Exemptions.delete.psbase.Count)"
        Write-Information "        orphans = $($Exemptions.numberOfOrphans)"
    }
}
else {
    Write-Information "Policy Exemptions not managed by EPAC."
}

if ($null -ne $PacEnvironment.policyAssignmentsFolder) {
    Write-Information "Role Assignment counts:"
    if ($RoleAssignments.numberOfChanges -eq 0) {
        Write-Information "    $($RoleAssignments.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($RoleAssignments.numberOfChanges) changes:"
        Write-Information "        add     = $($RoleAssignments.added.psbase.Count)"
        Write-Information "        remove  = $($RoleAssignments.removed.psbase.Count)"
    }
}

Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Output plan(s)"
$PolicyResourceChanges = $PolicyDefinitions.numberOfChanges
$PolicyResourceChanges += $PolicySetDefinitions.numberOfChanges
$PolicyResourceChanges += $Assignments.numberOfChanges
$PolicyResourceChanges += $Exemptions.numberOfChanges

$PolicyStage = "no"
$PlanFile = $PacEnvironment.policyPlanOutputFile
if ($PolicyResourceChanges -gt 0) {
    Write-Information "    Policy resource deployment required; writing Policy plan file '$PlanFile'"
    if (-not (Test-Path $PlanFile)) {
        $null = (New-Item $PlanFile -Force)
    }
    $null = $PolicyPlan | ConvertTo-Json -Depth 100 | Out-File -FilePath $PlanFile -Force
    $PolicyStage = "yes"
}
else {
    if (Test-Path $PlanFile) {
        $null = (Remove-Item $PlanFile)
    }
    Write-Information "    Skipping Policy deployment stage/step - no changes"
}

$roleStage = "no"
$PlanFile = $PacEnvironment.rolesPlanOutputFile
if ($RoleAssignments.numberOfChanges -gt 0) {
    Write-Information "    Role assignment changes required; writing Policy plan file '$PlanFile'"
    if (-not (Test-Path $PlanFile)) {
        $null = (New-Item $PlanFile -Force)
    }
    $null = $rolesPlan | ConvertTo-Json -Depth 100 | Out-File -FilePath $PlanFile -Force
    $roleStage = "yes"
}
else {
    if (Test-Path $PlanFile) {
        $null = (Remove-Item $PlanFile)
    }
    Write-Information "    Skipping Role Assignment stage/step - no changes"
}
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information ""

switch ($DevOpsType) {
    ado {
        Write-Host "##vso[task.setvariable variable=deployPolicyChanges;isOutput=true]$($PolicyStage)"
        Write-Host "##vso[task.setvariable variable=deployRoleChanges;isOutput=true]$($roleStage)"
        break
    }
    gitlab {
        Add-Content "build.env" "deployPolicyChanges=$($PolicyStage)"
        Add-Content "build.env" "deployRoleChanges=$($roleStage)"
    }
    default {
    }
}
