#Requires -PSEdition Core

<#
.SYNOPSIS
    Builds the deployment plans for the Policy as Code (PAC) environment.

.PARAMETER PacEnvironmentSelectorepac
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
    https://azure.github.io/enterprise-azure-policy-as-code/#deployment-scripts

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
    [string] $DevOpsType = "",

    [Parameter(HelpMessage = "Ignore scope tree errors")]
    [switch] $IgnoreScopeTreeErrors
)

$PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
}

Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# Initialize
$InformationPreference = "Continue"

$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("pid-3c88f740-55a8-4a96-9fba-30a81b52151a") 
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

# Getting existing Policy resources
$exemptionsAreNotManagedMessage = ""
$policyExemptionsFolder = $pacEnvironment.policyExemptionsFolder

$exemptionsFolderForPacEnvironment = "$($policyExemptionsFolder)/$($pacEnvironment.pacSelector)"
$exemptionsAreNotManaged = $false
if (!(Test-Path $policyExemptionsFolder -PathType Container)) {
    $exemptionsAreNotManagedMessage = "Policy Exemptions folder 'policyExemptions' not found. Exemptions not managed by this EPAC instance."
    $exemptionsAreNotManaged = $true
}
elseif (!(Test-Path $exemptionsFolderForPacEnvironment -PathType Container)) {
    $exemptionsAreNotManagedMessage = "Policy Exemptions are not managed by this EPAC instance's PaC environment $($pacEnvironment.pacSelector)!"
    $exemptionsAreNotManaged = $true
}

if ($IgnoreScopeTreeErrors) {
    Write-Warning "Ignoring scope tree errors"
    $scopeTable = Get-AzScopeTree -PacEnvironment $pacEnvironment -IgnoreScopeTreeErrors
}
else {
    $scopeTable = Get-AzScopeTree -PacEnvironment $pacEnvironment
}

$deployedPolicyResources = Get-AzPolicyResources -PacEnvironment $pacEnvironment -ScopeTable $scopeTable -SkipExemptions:$exemptionsAreNotManaged

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
    -DefinitionsRootFolder $pacEnvironment.policyDefinitionsFolder `
    -PacEnvironment $pacEnvironment `
    -DeployedDefinitions $deployedPolicyResources.policydefinitions `
    -Definitions $policyDefinitions `
    -AllDefinitions $allDefinitions `
    -ReplaceDefinitions $replaceDefinitions `
    -PolicyRoleIds $policyRoleIds

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
    -DefinitionsRootFolder $pacEnvironment.policySetDefinitionsFolder `
    -PacEnvironment $pacEnvironment `
    -DeployedDefinitions $deployedPolicyResources.policysetdefinitions `
    -Definitions $policySetDefinitions `
    -AllDefinitions $allDefinitions `
    -ReplaceDefinitions $replaceDefinitions `
    -PolicyRoleIds $policyRoleIds

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
    added           = @()
    removed         = @()
}
$allAssignments = @{}

Build-AssignmentPlan `
    -AssignmentsRootFolder $pacEnvironment.policyAssignmentsFolder `
    -PacEnvironment $pacEnvironment `
    -ScopeTable $scopeTable `
    -DeployedPolicyResources $deployedPolicyResources `
    -Assignments $assignments `
    -RoleAssignments $roleAssignments `
    -AllDefinitions $allDefinitions `
    -AllAssignments $allAssignments `
    -ReplaceDefinitions $replaceDefinitions `
    -PolicyRoleIds $policyRoleIds

$exemptions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfOrphans = 0
    numberOfExpired = 0
    numberOfChanges = 0
    numberUnchanged = 0
}

# Process exemption JSON files
Build-ExemptionsPlan `
    -ExemptionsRootFolder $exemptionsFolderForPacEnvironment `
    -ExemptionsAreNotManagedMessage $exemptionsAreNotManagedMessage `
    -PacEnvironment $pacEnvironment `
    -AllAssignments $allAssignments `
    -Assignments $assignments `
    -DeployedExemptions $deployedPolicyResources.policyExemptions `
    -Exemptions $exemptions

# Output Plan
$pacOwnerId = $pacEnvironment.pacOwnerId
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

if ($null -ne $pacEnvironment.policyDefinitionsFolder) {
    Write-Information "Policy counts:"
    Write-Information "    $($policyDefinitions.numberUnchanged) unchanged"
    if ($policyDefinitions.numberOfChanges -eq 0) {
        Write-Information "    $($policyDefinitions.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($policyDefinitions.numberOfChanges) changes:"
        Write-Information "        new     = $($policyDefinitions.new.psbase.Count)"
        Write-Information "        update  = $($policyDefinitions.update.psbase.Count)"
        Write-Information "        replace = $($policyDefinitions.replace.psbase.Count)"
        Write-Information "        delete  = $($policyDefinitions.delete.psbase.Count)"
    }
}
else {
    Write-Information "Policy definitions not managed by EPAC."
}

if ($null -ne $pacEnvironment.policySetDefinitionsFolder) {
    Write-Information "Policy Set counts:"
    Write-Information "    $($policySetDefinitions.numberUnchanged) unchanged"
    if ($policySetDefinitions.numberOfChanges -eq 0) {
        Write-Information "    $($policySetDefinitions.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($policySetDefinitions.numberOfChanges) changes:"
        Write-Information "        new     = $($policySetDefinitions.new.psbase.Count)"
        Write-Information "        update  = $($policySetDefinitions.update.psbase.Count)"
        Write-Information "        replace = $($policySetDefinitions.replace.psbase.Count)"
        Write-Information "        delete  = $($policySetDefinitions.delete.psbase.Count)"
    }
}
else {
    Write-Information "Policy Set definitions not managed by EPAC."
}

if ($null -ne $pacEnvironment.policyAssignmentsFolder) {
    Write-Information "Policy Assignment counts:"
    Write-Information "    $($assignments.numberUnchanged) unchanged"
    if ($assignments.numberOfChanges -eq 0) {
        Write-Information "    $($assignments.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($assignments.numberOfChanges) changes:"
        Write-Information "        new     = $($assignments.new.psbase.Count)"
        Write-Information "        update  = $($assignments.update.psbase.Count)"
        Write-Information "        replace = $($assignments.replace.psbase.Count)"
        Write-Information "        delete  = $($assignments.delete.psbase.Count)"
    }
    Write-Information "Role Assignment counts:"
    if ($roleAssignments.numberOfChanges -eq 0) {
        Write-Information "    $($roleAssignments.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($roleAssignments.numberOfChanges) changes:"
        Write-Information "        add     = $($roleAssignments.added.psbase.Count)"
        Write-Information "        remove  = $($roleAssignments.removed.psbase.Count)"
    }
}
else {
    Write-Information "Policy definitions not managed by EPAC."
}

if ($exemptionsAreNotManaged) {
    Write-Warning $exemptionsAreNotManagedMessage
}
else {
    Write-Information "Policy Exemption counts:"
    Write-Information "    $($exemptions.numberUnchanged) unchanged"
    Write-Information "    $($exemptions.numberOfOrphans) orphaned"
    Write-Information "    $($exemptions.numberOfExpired) expired"
    if ($exemptions.numberOfChanges -eq 0) {
        Write-Information "    $($exemptions.numberOfChanges) changes"
    }
    else {
        Write-Information "    $($exemptions.numberOfChanges) changes:"
        Write-Information "        new     = $($exemptions.new.psbase.Count)"
        Write-Information "        update  = $($exemptions.update.psbase.Count)"
        Write-Information "        replace = $($exemptions.replace.psbase.Count)"
        Write-Information "        delete  = $($exemptions.delete.psbase.Count)"
    }
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
    Write-Information "    Policy resource deployment required; writing Policy plan file '$planFile'"
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

switch ($DevOpsType) {
    ado {
        Write-Host "##vso[task.setvariable variable=deployPolicyChanges;isOutput=true]$($policyStage)"
        Write-Host "##vso[task.setvariable variable=deployRoleChanges;isOutput=true]$($roleStage)"
        break
    }
    gitlab {
        Add-Content "build.env" "deployPolicyChanges=$($policyStage)"
        Add-Content "build.env" "deployRoleChanges=$($roleStage)"
    }
    default {
    }
}
