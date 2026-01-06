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

.PARAMETER BuildExemptionsOnly
    If set, only build the exemptions plan.

.PARAMETER SkipExemptions
    If set, do not build the exemptions plan.

.PARAMETER Interactive
    Script is used interactively. Script can prompt the interactive user for input.

.PARAMETER DevOpsType
    If set, outputs variables consumable by conditions in a DevOps pipeline. Valid values are '', 'ado' and 'gitlab'.

.PARAMETER SkipNotScopedExemptions
    If set, skip exemptions that are not scoped.

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

    [Parameter(HelpMessage = "If set, do not build the exemptions plan.")]
    [switch] $SkipExemptions,

    [Parameter(HelpMessage = "Script is used interactively. Script can prompt the interactive user for input.")]
    [switch] $Interactive,

    [Parameter(HelpMessage = "If set, outputs variables consumable by conditions in a DevOps pipeline.")]
    [ValidateSet("ado", "gitlab", "")]
    [string] $DevOpsType = "",

    [switch]$SkipNotScopedExemptions,

    [Parameter(HelpMessage = "Level of detail for diff output: standard (default, current behavior), detailed (property-level changes with metadata/arrays).")]
    [ValidateSet("standard", "detailed")]
    [string] $DiffGranularity = "standard"
)

$PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
}

Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue
$Global:epacInfoStream = @()

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# Initialize
$InformationPreference = "Continue"
$scriptStartTime = Get-Date

# Display welcome header
Write-ModernHeader -Title "Enterprise Policy as Code (EPAC)" -Subtitle "Building Deployment Plans" -HeaderColor Magenta -SubtitleColor Magenta

$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive -DeploymentDefaultContext $pacEnvironment.defaultContext

# Resolve DiffGranularity with configuration precedence: CLI → env var → global-settings → default
if ($PSBoundParameters.ContainsKey('DiffGranularity') -and $DiffGranularity -ne "standard") {
    # CLI parameter explicitly provided, use it
    Write-Information "Using DiffGranularity from CLI parameter: $DiffGranularity"
}
elseif ($env:EPAC_DIFF_GRANULARITY) {
    # Environment variable set
    $DiffGranularity = $env:EPAC_DIFF_GRANULARITY
    Write-Information "Using DiffGranularity from environment variable: $DiffGranularity"
}
elseif ($pacEnvironment.outputPreferences -and $pacEnvironment.outputPreferences.diffGranularity) {
    # Global settings configuration
    $DiffGranularity = $pacEnvironment.outputPreferences.diffGranularity
    Write-Information "Using DiffGranularity from global-settings: $DiffGranularity"
}
# else: use default "summary" (already set in parameter)

# Set global variable for helper functions to check
$Global:EPAC_DiffGranularity = $DiffGranularity

# Set flag to suppress intermediate processing output for ChangeDetails mode
$suppressProcessingOutput = ($DiffGranularity -eq "ChangeDetails")

# Display environment information
Write-ModernSection -Title "Environment Configuration" -Color Blue
Write-ModernStatus -Message "PAC Environment: $($pacEnvironment.pacSelector)" -Status "info" -Indent 2
Write-ModernStatus -Message "Deployment Root: $($pacEnvironment.deploymentRootScope)" -Status "info" -Indent 2
Write-ModernStatus -Message "Tenant ID: $($pacEnvironment.tenantId)" -Status "info" -Indent 2
Write-ModernStatus -Message "Cloud: $($pacEnvironment.cloud)" -Status "info" -Indent 2

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-ModernStatus -Message "Telemetry is enabled" -Status "info" -Indent 2
    Submit-EPACTelemetry -Cuapid "pid-3c88f740-55a8-4a96-9fba-30a81b52151a" -DeploymentRootScope $pacEnvironment.deploymentRootScope
}
else {
    Write-ModernStatus -Message "Telemetry is disabled" -Status "info" -Indent 2
}

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

# Validate parameter conflicts
if ($BuildExemptionsOnly -and $SkipExemptions) {
    Write-Error -Message "The parameters -BuildExemptionsOnly and -SkipExemptions cannot be used together. Exiting..."
    exit
}

# Define resource types and their configuration
$resourceTypes = @(
    @{
        Name                    = "Policy definitions"
        BuildFlag               = "buildPolicyDefinitions"
        Folder                  = $policyDefinitionsFolder
        IncludeInExemptionsOnly = $false
        IncludeInSkipExemptions = $true
    },
    @{
        Name                    = "Policy Set definitions"
        BuildFlag               = "buildPolicySetDefinitions"
        Folder                  = $policySetDefinitionsFolder
        IncludeInExemptionsOnly = $false
        IncludeInSkipExemptions = $true
    },
    @{
        Name                    = "Policy Assignments"
        BuildFlag               = "buildPolicyAssignments"
        Folder                  = $policyAssignmentsFolder
        IncludeInExemptionsOnly = $false
        IncludeInSkipExemptions = $true
    },
    @{
        Name                    = "Policy Exemptions"
        BuildFlag               = "buildPolicyExemptions"
        Folder                  = $null  # Special handling required
        IncludeInExemptionsOnly = $true
        IncludeInSkipExemptions = $false
        IsManaged               = $exemptionsAreManaged
        NotManagedMessage       = $exemptionsAreNotManagedMessage
    }
)

# Determine build mode and add appropriate warning
if ($BuildExemptionsOnly) {
    $null = $warningMessages.Add("Building only the Exemptions plan. Policy, Policy Set, and Assignment plans will not be built.")
}
elseif ($SkipExemptions) {
    $null = $warningMessages.Add("Building only Policy, Policy Set, and Assignment plans. Exemption plans will not be built.")
}

# Process each resource type based on build mode
foreach ($resourceType in $resourceTypes) {
    $shouldInclude = $false
    # Determine if this resource type should be included based on build mode
    if ($BuildExemptionsOnly) {
        $shouldInclude = $resourceType.IncludeInExemptionsOnly
    }
    elseif ($SkipExemptions) {
        $shouldInclude = $resourceType.IncludeInSkipExemptions
    }
    else {
        # Default mode - include all managed resources
        $shouldInclude = $true
    }
    if ($shouldInclude) {
        # Special handling for exemptions
        if ($resourceType.Name -eq "Policy Exemptions") {
            if ($resourceType.IsManaged) {
                $buildSelections[$resourceType.BuildFlag] = $true
                $buildSelections.buildAny = $true
            }
            else {
                $null = $warningMessages.Add($resourceType.NotManagedMessage)
                if ($BuildExemptionsOnly) {
                    $null = $warningMessages.Add("Policy Exemptions plan will not be built. Exiting...")
                }
            }
        }
        else {
            # Standard folder-based resource types
            if (Test-Path $resourceType.Folder -PathType Container) {
                $buildSelections[$resourceType.BuildFlag] = $true
                $buildSelections.buildAny = $true
            }
            else {
                $null = $warningMessages.Add("$($resourceType.Name) '$($resourceType.Folder)' folder not found. $($resourceType.Name) not managed by this EPAC instance.")
            }
        }
    }
}

# Final validation - ensure at least one resource type is being built
if (-not $buildSelections.buildAny) {
    $null = $warningMessages.Add("No Policies, Policy Set, Assignment, or Exemptions managed by this EPAC instance found. No plans will be built. Exiting...")
}

if ($warningMessages.Count -gt 0) {
    Write-ModernSection -Title "Configuration Warnings" -Color Yellow
    foreach ($warningMessage in $warningMessages) {
        Write-ModernStatus -Message $warningMessage -Status "warning" -Indent 2

        if ($DevOpsType -eq "ado") {
            Write-Host "##vso[task.logissue type=warning]$warningMessage"
        }
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
        #Write-ModernProgress -Activity "Analyzing Policy Definitions"
        # Process Policies
        Build-PolicyPlan `
            -DefinitionsRootFolder $policyDefinitionsFolder `
            -PacEnvironment $pacEnvironment `
            -DeployedDefinitions $deployedPolicyResources.policydefinitions `
            -Definitions $policyDefinitions `
            -AllDefinitions $allDefinitions `
            -ReplaceDefinitions $replaceDefinitions `
            -PolicyRoleIds $policyRoleIds `
            -DiffGranularity $DiffGranularity
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
        #Write-ModernProgress -Activity "Analyzing Policy Set Definitions"
        # Process Policy Sets
        Build-PolicySetPlan `
            -DefinitionsRootFolder $policySetDefinitionsFolder `
            -PacEnvironment $pacEnvironment `
            -DeployedDefinitions $deployedPolicyResources.policysetdefinitions `
            -Definitions $policySetDefinitions `
            -AllDefinitions $allDefinitions `
            -ReplaceDefinitions $replaceDefinitions `
            -PolicyRoleIds $policyRoleIds `
            -DiffGranularity $DiffGranularity
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
        #Write-ModernProgress -Activity "Analyzing Policy Assignments"
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
            -DeprecatedHash $deprecatedHash `
            -DiffGranularity $DiffGranularity
    }

    if ($buildSelections.buildPolicyExemptions) {
        #Write-ModernProgress -Activity "Analyzing Policy Exemptions"
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
                -SkipNotScopedExemptions `
                -DiffGranularity $DiffGranularity
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
                -Exemptions $exemptions `
                -DiffGranularity $DiffGranularity
        }
    }

    Write-ModernHeader -Title "EPAC Deployment Plan Summary" -Subtitle "Policy as Code Resource Analysis" -HeaderColor Magenta -SubtitleColor Magenta

    if ($buildSelections.buildPolicyDefinitions) {
        $policyChanges = @{
            new     = $policyDefinitions.new.psbase.Count
            update  = $policyDefinitions.update.psbase.Count
            replace = $policyDefinitions.replace.psbase.Count
            delete  = $policyDefinitions.delete.psbase.Count
        }
        Write-ModernCountSummary -Type "Policy Definitions" -Unchanged $policyDefinitions.numberUnchanged -TotalChanges $policyDefinitions.numberOfChanges -Changes $policyChanges
    }

    if ($buildSelections.buildPolicySetDefinitions) {
        $policySetChanges = @{
            new     = $policySetDefinitions.new.psbase.Count
            update  = $policySetDefinitions.update.psbase.Count
            replace = $policySetDefinitions.replace.psbase.Count
            delete  = $policySetDefinitions.delete.psbase.Count
        }
        Write-ModernCountSummary -Type "Policy Set Definitions" -Unchanged $policySetDefinitions.numberUnchanged -TotalChanges $policySetDefinitions.numberOfChanges -Changes $policySetChanges
    }

    if ($buildSelections.buildPolicyAssignments) {
        $assignmentChanges = @{
            new     = $assignments.new.psbase.Count
            update  = $assignments.update.psbase.Count
            replace = $assignments.replace.psbase.Count
            delete  = $assignments.delete.psbase.Count
        }
        Write-ModernCountSummary -Type "Policy Assignments" -Unchanged $assignments.numberUnchanged -TotalChanges $assignments.numberOfChanges -Changes $assignmentChanges
        
        $roleChanges = @{
            add    = $roleAssignments.added.psbase.Count
            update = $roleAssignments.updated.psbase.Count
            remove = $roleAssignments.removed.psbase.Count
        }
        Write-ModernCountSummary -Type "Role Assignments" -Unchanged 0 -TotalChanges $roleAssignments.numberOfChanges -Changes $roleChanges
    }

    if ($buildSelections.buildPolicyExemptions) {
        $exemptionChanges = @{
            new     = $exemptions.new.psbase.Count
            update  = $exemptions.update.psbase.Count
            replace = $exemptions.replace.psbase.Count
            delete  = $exemptions.delete.psbase.Count
        }
        Write-ModernCountSummary -Type "Policy Exemptions" -Unchanged $exemptions.numberUnchanged -TotalChanges $exemptions.numberOfChanges -Changes $exemptionChanges -Orphaned $exemptions.numberOfOrphans -Expired $exemptions.numberOfExpired
    }

    # Render detailed diffs if granularity is detailed
    if ($DiffGranularity -ne "standard") {
        Write-ModernSection -Title "Detailed Changes" -Color Cyan
        
        # Policy Definitions
        if ($buildSelections.buildPolicyDefinitions) {
            if ($policyDefinitions.new.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Definitions" -Resources $policyDefinitions.new -Operation "new" -Granularity $DiffGranularity -Indent 2
            }
            if ($policyDefinitions.update.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Definitions" -Resources $policyDefinitions.update -Operation "update" -Granularity $DiffGranularity -Indent 2
            }
            if ($policyDefinitions.replace.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Definitions" -Resources $policyDefinitions.replace -Operation "replace" -Granularity $DiffGranularity -Indent 2
            }
            if ($policyDefinitions.delete.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Definitions" -Resources $policyDefinitions.delete -Operation "delete" -Granularity $DiffGranularity -Indent 2
            }
        }
        
        # Policy Set Definitions
        if ($buildSelections.buildPolicySetDefinitions) {
            if ($policySetDefinitions.new.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Set Definitions" -Resources $policySetDefinitions.new -Operation "new" -Granularity $DiffGranularity -Indent 2
            }
            if ($policySetDefinitions.update.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Set Definitions" -Resources $policySetDefinitions.update -Operation "update" -Granularity $DiffGranularity -Indent 2
            }
            if ($policySetDefinitions.replace.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Set Definitions" -Resources $policySetDefinitions.replace -Operation "replace" -Granularity $DiffGranularity -Indent 2
            }
            if ($policySetDefinitions.delete.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Set Definitions" -Resources $policySetDefinitions.delete -Operation "delete" -Granularity $DiffGranularity -Indent 2
            }
        }
        
        # Policy Assignments
        if ($buildSelections.buildPolicyAssignments) {
            if ($assignments.new.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Assignments" -Resources $assignments.new -Operation "new" -Granularity $DiffGranularity -Indent 2
            }
            if ($assignments.update.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Assignments" -Resources $assignments.update -Operation "update" -Granularity $DiffGranularity -Indent 2
            }
            if ($assignments.replace.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Assignments" -Resources $assignments.replace -Operation "replace" -Granularity $DiffGranularity -Indent 2
            }
            if ($assignments.delete.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Assignments" -Resources $assignments.delete -Operation "delete" -Granularity $DiffGranularity -Indent 2
            }
        }
        
        # Policy Exemptions
        if ($buildSelections.buildPolicyExemptions) {
            if ($exemptions.new.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Exemptions" -Resources $exemptions.new -Operation "new" -Granularity $DiffGranularity -Indent 2
            }
            if ($exemptions.update.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Exemptions" -Resources $exemptions.update -Operation "update" -Granularity $DiffGranularity -Indent 2
            }
            if ($exemptions.replace.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Exemptions" -Resources $exemptions.replace -Operation "replace" -Granularity $DiffGranularity -Indent 2
            }
            if ($exemptions.delete.psbase.Count -gt 0) {
                Write-ModernDiff -ResourceType "Policy Exemptions" -Resources $exemptions.delete -Operation "delete" -Granularity $DiffGranularity -Indent 2
            }
        }
        
        # Role Assignments
        if ($roleAssignments.added.Count -gt 0) {
            Write-Host ""
            $prefix = "  "
            Write-Host "$($prefix)Role Assignments:" -ForegroundColor Cyan
            
            # Group role assignments by assignment ID
            $groupedRoles = @{}
            foreach ($role in $roleAssignments.added) {
                $assignmentId = if ($role.assignmentId) { $role.assignmentId } else { "Unknown Assignment" }
                if (-not $groupedRoles.ContainsKey($assignmentId)) {
                    $groupedRoles[$assignmentId] = @()
                }
                $groupedRoles[$assignmentId] += $role
            }
            
            # Display grouped role assignments
            foreach ($assignmentId in ($groupedRoles.Keys | Sort-Object)) {
                $roles = $groupedRoles[$assignmentId]
                
                # Extract assignment name from ID for cleaner display
                $assignmentName = if ($assignmentId -match '/policyAssignments/([^/]+)$') {
                    $matches[1]
                } else {
                    $assignmentId
                }
                
                Write-Host ""
                Write-Host "$($prefix)  For Policy Assignment: $assignmentName" -ForegroundColor Cyan
                if ($assignmentId -ne "Unknown Assignment") {
                    Write-Host "$($prefix)    $assignmentId" -ForegroundColor DarkGray
                }
                
                foreach ($role in $roles) {
                    $roleDisplayName = if ($role.displayName) { $role.displayName } else { "Role Assignment" }
                    Write-Host "$($prefix)    ✓ Add: $roleDisplayName" -ForegroundColor Green
                    
                    # Handle missing principal ID (will be assigned during deployment)
                    $principalIdDisplay = if ([string]::IsNullOrEmpty($role.principalId)) { 
                        "<will be assigned during deployment>" 
                    } else { 
                        $role.principalId 
                    }
                    Write-Host "$($prefix)      • Principal ID: $principalIdDisplay" -ForegroundColor Gray
                    Write-Host "$($prefix)      • Role: $($role.roleDisplayName)" -ForegroundColor Gray
                    Write-Host "$($prefix)      • Scope: $($role.scope)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        if ($roleAssignments.removed.Count -gt 0) {
            if ($roleAssignments.added.Count -eq 0) {
                Write-Host ""
                $prefix = "  "
                Write-Host "$($prefix)Role Assignments:" -ForegroundColor Cyan
            }
            
            # Group role assignments by assignment ID for removals too
            $groupedRoles = @{}
            foreach ($role in $roleAssignments.removed) {
                $assignmentId = if ($role.assignmentId) { $role.assignmentId } else { "Unknown Assignment" }
                if (-not $groupedRoles.ContainsKey($assignmentId)) {
                    $groupedRoles[$assignmentId] = @()
                }
                $groupedRoles[$assignmentId] += $role
            }
            
            # Display grouped role assignments
            foreach ($assignmentId in ($groupedRoles.Keys | Sort-Object)) {
                $roles = $groupedRoles[$assignmentId]
                
                # Extract assignment name from ID for cleaner display
                $assignmentName = if ($assignmentId -match '/policyAssignments/([^/]+)$') {
                    $matches[1]
                } else {
                    $assignmentId
                }
                
                Write-Host ""
                Write-Host "$($prefix)  For Policy Assignment: $assignmentName" -ForegroundColor Cyan
                if ($assignmentId -ne "Unknown Assignment") {
                    Write-Host "$($prefix)    $assignmentId" -ForegroundColor DarkGray
                }
                
                foreach ($role in $roles) {
                    $roleDisplayName = if ($role.displayName) { $role.displayName } else { "Role Assignment" }
                    Write-Host "$($prefix)    ✗ Remove: $roleDisplayName" -ForegroundColor Red
                    Write-Host "$($prefix)      • Principal ID: $($role.principalId)" -ForegroundColor Gray
                    Write-Host "$($prefix)      • Role: $($role.roleDisplayName)" -ForegroundColor Gray
                    Write-Host "$($prefix)      • Scope: $($role.scope)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
    }

}

Write-ModernSection -Title "Deployment Plan Output" -Color Green
$policyResourceChanges = $policyDefinitions.numberOfChanges
$policyResourceChanges += $policySetDefinitions.numberOfChanges
$policyResourceChanges += $assignments.numberOfChanges
$policyResourceChanges += $exemptions.numberOfChanges

$policyStage = "no"
$planFile = $pacEnvironment.policyPlanOutputFile
if ($policyResourceChanges -gt 0) {
    # Normalize path separators for consistent console output
    $normalizedPlanFile = $planFile -replace '[\\/]+', [System.IO.Path]::DirectorySeparatorChar
    Write-ModernStatus -Message "Policy deployment plan created: $normalizedPlanFile" -Status "success" -Indent 2
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
    Write-ModernStatus -Message "Policy deployment stage skipped - no changes detected" -Status "skip" -Indent 2
}

$roleStage = "no"
$planFile = $pacEnvironment.rolesPlanOutputFile
if ($roleAssignments.numberOfChanges -gt 0) {
    # Normalize path separators for consistent console output
    $normalizedPlanFile = $planFile -replace '[\\/]+', [System.IO.Path]::DirectorySeparatorChar
    Write-ModernStatus -Message "Role assignment plan created: $normalizedPlanFile" -Status "success" -Indent 2
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
    Write-ModernStatus -Message "Role assignment stage skipped - no changes detected" -Status "skip" -Indent 2
}

# Export diff artifact if granularity is detailed
if ($DiffGranularity -ne "standard" -and ($policyResourceChanges -gt 0 -or $roleAssignments.numberOfChanges -gt 0)) {
    # Extract output path from the policy plan file path (parent directory)
    $outputPath = Split-Path -Parent $pacEnvironment.policyPlanOutputFile
    Export-PolicyDiffArtifact -PolicyPlan $policyPlan -RolesPlan $rolesPlan -OutputFolder $outputPath
    $diffPath = Join-Path $outputPath "policy-diff.json"
    # Normalize path separators for consistent console output
    $normalizedDiffPath = $diffPath -replace '[\\/]+', [System.IO.Path]::DirectorySeparatorChar
    Write-ModernStatus -Message "Diff artifact exported to: $normalizedDiffPath" -Status "success" -Indent 2
}

Write-Host ""

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

# Display completion message
$totalTime = (Get-Date) - $scriptStartTime
Write-ModernHeader -Title "EPAC Build Complete" -Subtitle "Deployment plans generated successfully" -HeaderColor Green -SubtitleColor DarkGreen
Write-ModernStatus -Message "Total execution time: $($totalTime.ToString('mm\:ss\.fff'))" -Status "info"

# Write extended information to pipeline logs if needed
if ($DevOpsType -ne "" -and ($policyResourceChanges -gt 0 -or $roleAssignments.numberOfChanges -gt 0)) {
    Write-Information ""
    Write-Information "=== Change Summary for Pipeline ==="
    Write-Information "Policy changes: $policyResourceChanges"
    Write-Information "Role changes: $($roleAssignments.numberOfChanges)"
    Write-Information "==================================="
}
