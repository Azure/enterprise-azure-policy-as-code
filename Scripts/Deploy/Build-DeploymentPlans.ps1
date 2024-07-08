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
    https://azure.github.io/enterprise-azure-policy-as-code/#deployment-scripts

#>

[CmdletBinding()]
param (
    [parameter(HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector = "",

    [Parameter(HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(HelpMessage = "Output folder path for plan files. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Output'.")]
    [string]$OutputFolder,

    [Parameter(HelpMessage = "If set, only build the exemptions plan.")]
    [switch] $BuildExemptionsOnly,

    [Parameter(HelpMessage = "Script is used interactively. Script can prompt the interactive user for input.")]
    [switch] $Interactive,

    [Parameter(HelpMessage = "If set, outputs variables consumable by conditions in a DevOps pipeline.")]
    [ValidateSet("ado", "gitlab", "")]
    [string] $DevOpsType = "",

    [switch]$SkipNotScopedExemptions
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
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive -DeploymentDefaultContext $pacEnvironment.defaultContext

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    Submit-EPACTelemetry -Cuapid "pid-3c88f740-55a8-4a96-9fba-30a81b52151a" -DeploymentRootScope $pacEnvironment.deploymentRootScope
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

#region plan data structures
$buildSelections = @{
    buildAny                  = $false
    buildPolicyDefinitions    = $false
    buildPolicySetDefinitions = $false
    buildPolicyAssignments    = $false
    buildPolicyExemptions     = $false
}
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
$policySetDefinitions = @{
    new             = @{}
    update          = @{}
    replace         = @{}
    delete          = @{}
    numberOfChanges = 0
    numberUnchanged = 0
}
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
    added           = [System.Collections.ArrayList]::new()
    updated         = [System.Collections.ArrayList]::new()
    removed         = [System.Collections.ArrayList]::new()
}
$allAssignments = @{}
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
$policyDefinitionsFolder = $pacEnvironment.policyDefinitionsFolder
$policySetDefinitionsFolder = $pacEnvironment.policySetDefinitionsFolder
$policyAssignmentsFolder = $pacEnvironment.policyAssignmentsFolder
$policyExemptionsFolder = $pacEnvironment.policyExemptionsFolder
$policyExemptionsFolderForPacEnvironment = "$($policyExemptionsFolder)/$($pacEnvironment.pacSelector)"
#endregion plan data structures

#region calculate which plans need to be built
$warningMessages = [System.Collections.ArrayList]::new()
$exemptionsAreNotManagedMessage = $null
$exemptionsAreManaged = $true
if (!(Test-Path $policyExemptionsFolder -PathType Container)) {
    $exemptionsAreNotManagedMessage = "Policy Exemptions folder '$policyExemptionsFolder not found. Exemptions not managed by this EPAC instance."
    $exemptionsAreManaged = $false
}
elseif (!(Test-Path $policyExemptionsFolderForPacEnvironment -PathType Container)) {
    $exemptionsAreNotManagedMessage = "Policy Exemptions folder '$policyExemptionsFolderForPacEnvironment' for PaC environment $($pacEnvironment.pacSelector) not found. Exemptions not managed by this EPAC instance."
    $exemptionsAreManaged = $false
}
$localBuildExemptionsOnly = $BuildExemptionsOnly
# $localBuildExemptionsOnly = $true
# $VerbosePreference = "Continue"
if ($localBuildExemptionsOnly) {
    $null = $warningMessages.Add("Building only the Exemptions plan. Policy, Policy Set, and Assignment plans will not be built.")
    if ($exemptionsAreManaged) {
        $buildSelections.buildPolicyExemptions = $true
        $buildSelections.buildAny = $true
    }
    else {
        $null = $warningMessages.Add($exemptionsAreNotManagedMessage)
        $null = $warningMessages.Add("Policy Exemptions plan will not be built. Exiting...")
    }
    $buildSelections.buildPolicyDefinitions = $false
    $buildSelections.buildPolicySetDefinitions = $false
    $buildSelections.buildPolicyAssignments = $false
}
else {
    if (!(Test-Path $policyDefinitionsFolder -PathType Container)) {
        $null = $warningMessages.Add("Policy definitions '$policyDefinitionsFolder' folder not found. Policy definitions not managed by this EPAC instance.")
    }
    else {
        $buildSelections.buildPolicyDefinitions = $true
        $buildSelections.buildAny = $true
    }
    if (!(Test-Path $policySetDefinitionsFolder -PathType Container)) {
        $null = $warningMessages.Add("Policy Set definitions '$policySetDefinitionsFolder' folder not found. Policy Set definitions not managed by this EPAC instance.")
    }
    else {
        $buildSelections.buildPolicySetDefinitions = $true
        $buildSelections.buildAny = $true
    }
    if (!(Test-Path $policyAssignmentsFolder -PathType Container)) {
        $null = $warningMessages.Add("Policy Assignments '$policyAssignmentsFolder' folder not found. Policy Assignments not managed by this EPAC instance.")
    }
    else {
        $buildSelections.buildPolicyAssignments = $true
        $buildSelections.buildAny = $true
    }
    if ($exemptionsAreManaged) {
        $buildSelections.buildPolicyExemptions = $true
        $buildSelections.buildAny = $true
    }
    else {
        $null = $warningMessages.Add($exemptionsAreNotManagedMessage)
    }
    if (-not $buildSelections.buildAny) {
        $null = $warningMessages.Add("No Policies, Policy Set, Assignment, or Exemptions managed by this EPAC instance found. No plans will be built. Exiting...")
    }
}
if ($warningMessages.Count -gt 0) {
    foreach ($warningMessage in $warningMessages) {
        Write-Warning $warningMessage
    }
}
#endregion calculate which plans need to be built

if ($buildSelections.buildAny) {
    
    # get the scope table for the deployment root scope amd the resources
    $scopeTable = Build-ScopeTableForDeploymentRootScope -PacEnvironment $pacEnvironment
    $skipExemptions = -not $buildSelections.buildPolicyExemptions
    $skipRoleAssignments = -not $buildSelections.buildPolicyAssignments
    $deployedPolicyResources = Get-AzPolicyResources `
        -PacEnvironment $pacEnvironment `
        -ScopeTable $scopeTable `
        -SkipExemptions:$skipExemptions `
        -SkipRoleAssignments:$skipRoleAssignments

    # Calculate roleDefinitionIds for built-in and inherited Policies
    $readOnlyPolicyDefinitions = $deployedPolicyResources.policydefinitions.readOnly
    foreach ($id in $readOnlyPolicyDefinitions.Keys) {
        $deployedDefinitionProperties = Get-PolicyResourceProperties -PolicyResource $readOnlyPolicyDefinitions.$id
        if ($deployedDefinitionProperties.policyRule.then.details -and $deployedDefinitionProperties.policyRule.then.details.roleDefinitionIds) {
            $roleIds = $deployedDefinitionProperties.policyRule.then.details.roleDefinitionIds
            $null = $policyRoleIds.Add($id, $roleIds)
        }
    }

    # Populate allDefinitions.policydefinitions with all deployed definitions
    $allDeployedDefinitions = $deployedPolicyResources.policydefinitions.all
    foreach ($id in $allDeployedDefinitions.Keys) {
        $allDefinitions.policydefinitions[$id] = $allDeployedDefinitions.$id
    }

    if ($buildSelections.buildPolicyDefinitions) {
        # Process Policies
        Build-PolicyPlan `
            -DefinitionsRootFolder $policyDefinitionsFolder `
            -PacEnvironment $pacEnvironment `
            -DeployedDefinitions $deployedPolicyResources.policydefinitions `
            -Definitions $policyDefinitions `
            -AllDefinitions $allDefinitions `
            -ReplaceDefinitions $replaceDefinitions `
            -PolicyRoleIds $policyRoleIds
    }

    # Calculate roleDefinitionIds for built-in and inherited PolicySets
    $readOnlyPolicySetDefinitions = $deployedPolicyResources.policysetdefinitions.readOnly
    foreach ($id in $readOnlyPolicySetDefinitions.Keys) {
        $policySetProperties = Get-PolicyResourceProperties -PolicyResource $readOnlyPolicySetDefinitions.$id
        $roleIds = @{}
        foreach ($policyDefinition in $policySetProperties.policyDefinitions) {
            $policyId = $policyDefinition.policyDefinitionId
            if ($policyRoleIds.ContainsKey($policyId)) {
                $addRoleDefinitionIds = $PolicyRoleIds.$policyId
                foreach ($roleDefinitionId in $addRoleDefinitionIds) {
                    $roleIds[$roleDefinitionId] = "added"
                }
            }
        }
        if ($roleIds.psbase.Count -gt 0) {
            $null = $policyRoleIds.Add($id, $roleIds.Keys)
        }
    }

    # Populate allDefinitions.policysetdefinitions with deployed definitions
    $allDeployedDefinitions = $deployedPolicyResources.policysetdefinitions.all
    foreach ($id in $allDeployedDefinitions.Keys) {
        $allDefinitions.policysetdefinitions[$id] = $allDeployedDefinitions.$id
    }

    if ($buildSelections.buildPolicySetDefinitions) {
        # Process Policy Sets
        Build-PolicySetPlan `
            -DefinitionsRootFolder $policySetDefinitionsFolder `
            -PacEnvironment $pacEnvironment `
            -DeployedDefinitions $deployedPolicyResources.policysetdefinitions `
            -Definitions $policySetDefinitions `
            -AllDefinitions $allDefinitions `
            -ReplaceDefinitions $replaceDefinitions `
            -PolicyRoleIds $policyRoleIds
    }

    # Convert Policy and PolicySetDefinition to detailed Info
    $combinedPolicyDetails = Convert-PolicyResourcesToDetails `
        -AllPolicyDefinitions $allDefinitions.policydefinitions `
        -AllPolicySetDefinitions $allDefinitions.policysetdefinitions

    # Populate allAssignments
    $deployedPolicyAssignments = $deployedPolicyResources.policyassignments.managed
    foreach ($id  in $deployedPolicyAssignments.Keys) {
        $allAssignments[$id] = $deployedPolicyAssignments.$id
    }

    #region Process Deprecated
    $deprecatedHash = @{}
    foreach ($key in $combinedPolicyDetails.policies.keys) {
        if ($combinedPolicyDetails.policies.$key.isDeprecated) {
            $deprecatedHash[$combinedPolicyDetails.policies.$key.name] = $combinedPolicyDetails.policies.$key
        }
    }

    if ($buildSelections.buildPolicyAssignments) {
        # Process Assignment JSON files
        Build-AssignmentPlan `
            -AssignmentsRootFolder $policyAssignmentsFolder `
            -PacEnvironment $pacEnvironment `
            -ScopeTable $scopeTable `
            -DeployedPolicyResources $deployedPolicyResources `
            -Assignments $assignments `
            -RoleAssignments $roleAssignments `
            -AllAssignments $allAssignments `
            -ReplaceDefinitions $replaceDefinitions `
            -PolicyRoleIds $policyRoleIds `
            -CombinedPolicyDetails $combinedPolicyDetails `
            -DeprecatedHash $deprecatedHash
    }

    if ($buildSelections.buildPolicyExemptions) {
        # Process Exemption JSON files
        if ($SkipNotScopedExemptions) {
            Build-ExemptionsPlan `
                -ExemptionsRootFolder $policyExemptionsFolderForPacEnvironment `
                -ExemptionsAreNotManagedMessage $exemptionsAreNotManagedMessage `
                -PacEnvironment $pacEnvironment `
                -ScopeTable $scopeTable `
                -AllDefinitions $allDefinitions `
                -AllAssignments $allAssignments `
                -CombinedPolicyDetails $combinedPolicyDetails `
                -Assignments $assignments `
                -DeployedExemptions $deployedPolicyResources.policyExemptions `
                -Exemptions $exemptions `
                -SkipNotScopedExemptions
        }
        else {
            Build-ExemptionsPlan `
                -ExemptionsRootFolder $policyExemptionsFolderForPacEnvironment `
                -ExemptionsAreNotManagedMessage $exemptionsAreNotManagedMessage `
                -PacEnvironment $pacEnvironment `
                -ScopeTable $scopeTable `
                -AllDefinitions $allDefinitions `
                -AllAssignments $allAssignments `
                -CombinedPolicyDetails $combinedPolicyDetails `
                -Assignments $assignments `
                -DeployedExemptions $deployedPolicyResources.policyExemptions `
                -Exemptions $exemptions
        }
    }

    Write-Information "==================================================================================================="
    Write-Information "Summary"
    Write-Information "==================================================================================================="

    if ($buildSelections.buildPolicyDefinitions) {
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

    if ($buildSelections.buildPolicySetDefinitions) {
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

    if ($buildSelections.buildPolicyAssignments) {
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
            Write-Information "        update  = $($roleAssignments.updated.psbase.Count)"
            Write-Information "        remove  = $($roleAssignments.removed.psbase.Count)"
        }
    }

    if ($buildSelections.buildPolicyExemptions) {
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

}

Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Output plan(s); if any, will be written to the following file(s):"
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
