<#
.SYNOPSIS
    Simplified EPAC Hydration Kit installer for quick environment setup.

.DESCRIPTION
    This streamlined version of the EPAC Hydration Kit reduces complexity and setup time.
    It focuses on essential configuration with smart defaults, allowing optional enhancements
    to be added later through separate commands.

.PARAMETER TenantIntermediateRoot
    The Management Group ID that serves as your organizational root (e.g., "contoso").
    This will be the deploymentRootScope for your main EPAC environment.

.PARAMETER PacSelector
    Friendly name for your main EPAC environment. Defaults to "tenant01".

.PARAMETER ManagedIdentityLocation
    Azure region for Managed Identities used by DINE/Modify policies. If not specified,
    will prompt with available locations.

.PARAMETER DefinitionsRootFolder
    Path to the Definitions directory. Defaults to "./Definitions".

.PARAMETER OutputFolder
    Path to the Output directory. Defaults to "./Output".

.PARAMETER ImportExistingPolicies
    Switch to import existing policy assignments from the specified scope.

.PARAMETER PipelinePlatform
    DevOps platform: 'GitHub', 'AzureDevOps', or 'None'. Defaults to 'None'.

.PARAMETER UseModuleNotScript
    Use the EnterprisePolicyAsCode PowerShell module instead of local scripts.

.PARAMETER NonInteractive
    Run without prompts using defaults and provided parameters.

.PARAMETER ConfigFile
    Path to a configuration file (JSON/YAML) with settings.

.EXAMPLE
    Install-EpacHydration -TenantIntermediateRoot "contoso"
    
    Minimal setup with interactive prompts for required values.

.EXAMPLE
    Install-EpacHydration -TenantIntermediateRoot "contoso" -ImportExistingPolicies -PipelinePlatform GitHub -PipelineType StarterKit
    
    Setup with policy import and full StarterKit GitHub Actions pipelines.

.EXAMPLE
    Install-EpacHydration -TenantIntermediateRoot "contoso" -PipelinePlatform AzureDevOps -PipelineType StarterKit -BranchingFlow Release
    
    Setup with Azure DevOps pipelines using Release Flow branching strategy.

.EXAMPLE
    Install-EpacHydration -ConfigFile .\epac-config.json -NonInteractive
    
    Automated setup using configuration file.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code
#>
function Install-EpacHydration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $TenantIntermediateRoot,

        [Parameter(Mandatory = $false)]
        [string] $PacSelector = "tenant01",

        [Parameter(Mandatory = $false)]
        [string] $ManagedIdentityLocation,

        [Parameter(Mandatory = $false)]
        [string] $DefinitionsRootFolder = "./Definitions",

        [Parameter(Mandatory = $false)]
        [string] $OutputFolder = "./Output",

        [Parameter(Mandatory = $false)]
        [switch] $ImportExistingPolicies,

        [Parameter(Mandatory = $false)]
        [ValidateSet('GitHub', 'AzureDevOps', 'None')]
        [string] $PipelinePlatform = 'None',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Simple', 'StarterKit')]
        [string] $PipelineType = 'Simple',

        [Parameter(Mandatory = $false)]
        [ValidateSet('GitHub', 'Release')]
        [string] $BranchingFlow = 'GitHub',

        [Parameter(Mandatory = $false)]
        [switch] $UseModuleNotScript,

        [Parameter(Mandatory = $false)]
        [switch] $NonInteractive,

        [Parameter(Mandatory = $false)]
        [string] $ConfigFile
    )

    $PSDefaultParameterValues = @{
        "Write-Information:InformationVariable" = "+global:epacInfoStream"
    }

    Clear-Variable -Name epacInfoStream -Scope global -Force -ErrorAction SilentlyContinue

    $ErrorActionPreference = 'Stop'
    $InformationPreference = 'Continue'

    # Banner
    Write-ModernHeader -Title "EPAC Hydration Kit (Simplified v2)" -Subtitle "Quick Environment Setup"

    try {
        # Load configuration from file if provided
        if ($ConfigFile -and (Test-Path $ConfigFile)) {
            Write-ModernStatus -Message "Loading configuration from: $ConfigFile" -Status "info" -Indent 2
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            
            # Merge config file values with parameters (parameters take precedence)
            if (!$PSBoundParameters.ContainsKey('TenantIntermediateRoot') -and $config.tenantIntermediateRoot) {
                $TenantIntermediateRoot = $config.tenantIntermediateRoot
            }
            if (!$PSBoundParameters.ContainsKey('PacSelector') -and $config.pacSelector) {
                $PacSelector = $config.pacSelector
            }
            if (!$PSBoundParameters.ContainsKey('ManagedIdentityLocation') -and $config.managedIdentityLocation) {
                $ManagedIdentityLocation = $config.managedIdentityLocation
            }
            if (!$PSBoundParameters.ContainsKey('ImportExistingPolicies') -and $config.importExistingPolicies) {
                $ImportExistingPolicies = $config.importExistingPolicies
            }
            if (!$PSBoundParameters.ContainsKey('PipelinePlatform') -and $config.pipelinePlatform) {
                $PipelinePlatform = $config.pipelinePlatform
            }
            if (!$PSBoundParameters.ContainsKey('PipelineType') -and $config.pipelineType) {
                $PipelineType = $config.pipelineType
            }
            if (!$PSBoundParameters.ContainsKey('BranchingFlow') -and $config.branchingFlow) {
                $BranchingFlow = $config.branchingFlow
            }
            if (!$PSBoundParameters.ContainsKey('UseModuleNotScript') -and $config.useModuleNotScript) {
                $UseModuleNotScript = $config.useModuleNotScript
            }
            if (!$PSBoundParameters.ContainsKey('DefinitionsRootFolder') -and $config.definitionsRootFolder) {
                $DefinitionsRootFolder = $config.definitionsRootFolder
            }
            if (!$PSBoundParameters.ContainsKey('OutputFolder') -and $config.outputFolder) {
                $OutputFolder = $config.outputFolder
            }
        }

        # Validate TenantIntermediateRoot is provided
        if ([string]::IsNullOrWhiteSpace($TenantIntermediateRoot)) {
            if ($NonInteractive) {
                Write-Error "TenantIntermediateRoot is required. Provide it via parameter or config file."
                return
            }
            else {
                Write-ModernStatus -Message "TenantIntermediateRoot is required" -Status "warning" -Indent 2
                $TenantIntermediateRoot = Read-Host "Enter the Management Group ID for your organizational root (e.g., 'contoso')"
                if ([string]::IsNullOrWhiteSpace($TenantIntermediateRoot)) {
                    Write-Error "TenantIntermediateRoot cannot be empty"
                    return
                }
            }
        }

        # Prompt for ImportExistingPolicies if running interactively without config file and not already set
        if (!$PSBoundParameters.ContainsKey('ImportExistingPolicies') -and !$ConfigFile -and !$NonInteractive) {
            Write-Host ""
            Write-ModernStatus -Message "Would you like to import existing policy assignments from your environment?" -Status "info" -Indent 2
            Write-ModernStatus -Message "This will export current policies for review and migration to EPAC" -Status "info" -Indent 2
            $importChoice = Read-Host "Import existing policies? (y/N)"
            if ($importChoice -eq 'y' -or $importChoice -eq 'Y' -or $importChoice -eq 'yes' -or $importChoice -eq 'Yes') {
                $ImportExistingPolicies = $true
            }
        }

        # Prompt for PipelineType if creating pipelines interactively
        if ($PipelinePlatform -ne 'None' -and !$PSBoundParameters.ContainsKey('PipelineType') -and !$ConfigFile -and !$NonInteractive) {
            Write-Host ""
            Write-ModernStatus -Message "Choose pipeline template type:" -Status "info" -Indent 2
            Write-ModernStatus -Message "1. Simple - Basic single-file pipeline (quick start)" -Status "info" -Indent 3
            Write-ModernStatus -Message "2. StarterKit - Full EPAC templates with advanced features (recommended)" -Status "info" -Indent 3
            $pipelineChoice = Read-Host "Enter choice (1/2) [default: 1]"
            if ($pipelineChoice -eq '2') {
                $PipelineType = 'StarterKit'
                
                # Prompt for branching flow when using StarterKit
                Write-Host ""
                Write-ModernStatus -Message "Choose branching flow:" -Status "info" -Indent 2
                Write-ModernStatus -Message "1. GitHub Flow - Single main branch + feature branches (simpler)" -Status "info" -Indent 3
                Write-ModernStatus -Message "2. Release Flow - Main + release + feature branches (enterprise)" -Status "info" -Indent 3
                $flowChoice = Read-Host "Enter choice (1/2) [default: 1]"
                if ($flowChoice -eq '2') {
                    $BranchingFlow = 'Release'
                }
            }
        }

        # Step 1: Prerequisites Check
        Write-ModernSection -Title "Step 1/5: Checking Prerequisites" -Indent 0
        $prereqResult = Test-EpacPrerequisites -Quick
        if (!$prereqResult.Success) {
            Write-Error "Prerequisites check failed: $($prereqResult.Message)"
            return
        }

        # Step 2: Build Configuration
        Write-ModernSection -Title "Step 2/5: Building Configuration" -Indent 0
        $epacConfig = New-EpacConfiguration `
            -TenantIntermediateRoot $TenantIntermediateRoot `
            -PacSelector $PacSelector `
            -ManagedIdentityLocation $ManagedIdentityLocation `
            -DefinitionsRootFolder $DefinitionsRootFolder `
            -OutputFolder $OutputFolder `
            -NonInteractive:$NonInteractive

        if (!$epacConfig.Success) {
            Write-Error "Configuration failed: $($epacConfig.Message)"
            return
        }

        # Step 3: Deploy Azure Resources
        Write-ModernSection -Title "Step 3/5: Creating Azure Management Group Structure" -Indent 0
        $deployResult = Deploy-EpacResources -Configuration $epacConfig
        if (!$deployResult.Success) {
            Write-Error "Resource deployment failed: $($deployResult.Message)"
            return
        }

        # Step 4: Initialize Repository Structure
        Write-ModernSection -Title "Step 4/5: Creating Repository Structure and Files" -Indent 0
        $repoResult = Initialize-EpacRepository -Configuration $epacConfig
        if (!$repoResult.Success) {
            Write-Error "Repository initialization failed: $($repoResult.Message)"
            return
        }

        # Step 5: Optional Enhancements
        Write-ModernSection -Title "Step 5/5: Applying Optional Configurations" -Indent 0
        
        # Import existing policies if requested (after global-settings.jsonc is created)
        if ($ImportExistingPolicies) {
            $importResult = Import-EpacPolicies -Configuration $epacConfig -ExemptionFiles 'json'
            if (!$importResult.Success) {
                Write-ModernStatus -Message "Policy import had issues: $($importResult.Message)" -Status "warning" -Indent 2
            }
            else {
                Write-ModernStatus -Message "Successfully exported $($importResult.PolicyDefinitions) policy definitions" -Status "success" -Indent 2
                Write-ModernStatus -Message "Successfully exported $($importResult.PolicySetDefinitions) policy set definitions" -Status "success" -Indent 2
                Write-ModernStatus -Message "Successfully exported $($importResult.PolicyAssignments) policy assignments" -Status "success" -Indent 2
            }
        }

        # Create pipeline files if requested
        if ($PipelinePlatform -ne 'None') {
            Write-ModernStatus -Message "Creating $PipelinePlatform pipeline files ($PipelineType)" -Status "processing" -Indent 2
            $pipelineResult = New-EpacPipeline `
                -Platform $PipelinePlatform `
                -Configuration $epacConfig `
                -PipelineType $PipelineType `
                -BranchingFlow $BranchingFlow `
                -UseModule:$UseModuleNotScript
            if (!$pipelineResult.Success) {
                Write-Warning "Pipeline creation had issues: $($pipelineResult.Message)"
            }
            else {
                Write-ModernStatus -Message "Pipeline type: $($pipelineResult.Type)" -Status "success" -Indent 3
            }
        }

        # Success Summary
        Write-ModernHeader -Title "EPAC Environment Setup Complete!" -Subtitle "Configuration Summary"

        Write-ModernStatus -Message "Tenant: $($epacConfig.TenantId)" -Status "info" -Indent 2
        Write-ModernStatus -Message "Root MG: $TenantIntermediateRoot" -Status "info" -Indent 2
        Write-ModernStatus -Message "PacSelector: $PacSelector" -Status "info" -Indent 2
        Write-ModernStatus -Message "EPAC-Dev Root: $($epacConfig.EpacDevRoot)" -Status "info" -Indent 2
        Write-ModernStatus -Message "Definitions: $DefinitionsRootFolder" -Status "info" -Indent 2
        Write-ModernStatus -Message "Output: $OutputFolder" -Status "info" -Indent 2

        Write-ModernSection -Title "Next Steps" -Indent 0
        Write-ModernStatus -Message "1. Review generated files in: $DefinitionsRootFolder" -Status "info" -Indent 2
        Write-ModernStatus -Message "2. Test deployment to epac-dev:" -Status "info" -Indent 2
        Write-ModernStatus -Message "Build-DeploymentPlans -PacEnvironmentSelector epac-dev" -Status "info" -Indent 5
        Write-ModernStatus -Message "Deploy-PolicyPlan -PacEnvironmentSelector epac-dev" -Status "info" -Indent 5
        Write-ModernStatus -Message "Deploy-RolesPlan -PacEnvironmentSelector epac-dev" -Status "info" -Indent 5
        
        if ($PipelinePlatform -eq 'None') {
            Write-ModernStatus -Message "3. Optional: Create CI/CD pipeline:" -Status "info" -Indent 2
            Write-ModernStatus -Message "New-EpacPipeline -Platform GitHub" -Status "info" -Indent 5
        }

        Write-ModernStatus -Message "Documentation: https://aka.ms/epac" -Status "info" -Indent 2

        # Generate configuration template file with the values used
        Write-ModernSection -Title "Configuration Template" -Indent 0
        $configTemplatePath = Join-Path $OutputFolder "epac-hydration-config.jsonc"
        
        $configTemplate = @"
{
  // EPAC Hydration Kit Configuration Template
  // Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  // This file can be used with: Install-EpacHydration -ConfigFile <path-to-this-file> -NonInteractive

  // REQUIRED: The Management Group ID that serves as your organizational root
  // This will be the deploymentRootScope for your main EPAC environment
  "tenantIntermediateRoot": "$TenantIntermediateRoot",

  // Optional: Friendly name for your main EPAC environment (default: "tenant01")
  "pacSelector": "$PacSelector",

  // Optional: Azure region for Managed Identities used by DINE/Modify policies
  // If not specified and running interactively, you will be prompted
  "managedIdentityLocation": "$ManagedIdentityLocation",

  // Optional: Path to the Definitions directory (default: "./Definitions")
  "definitionsRootFolder": "$DefinitionsRootFolder",

  // Optional: Path to the Output directory (default: "./Output")
  "outputFolder": "$OutputFolder",

  // Optional: Import existing policy assignments from the specified scope
  // Set to true to import existing policies (default: false)
  "importExistingPolicies": $(if ($ImportExistingPolicies) { 'true' } else { 'false' }),

  // Optional: DevOps platform for CI/CD pipeline generation
  // Valid values: "GitHub", "AzureDevOps", "None" (default: "None")
  "pipelinePlatform": "$PipelinePlatform",

  // Optional: Pipeline template type
  // Valid values: "Simple", "StarterKit" (default: "Simple")
  // Simple: Basic single-file pipeline
  // StarterKit: Full EPAC pipeline templates with advanced features
  "pipelineType": "$PipelineType",

  // Optional: Branching flow for StarterKit pipelines
  // Valid values: "GitHub", "Release" (default: "GitHub")
  // GitHub: GitHub Flow (main + feature branches)
  // Release: Release Flow (main + release + feature branches)
  "branchingFlow": "$BranchingFlow",

  // Optional: Use the EnterprisePolicyAsCode PowerShell module instead of local scripts
  // Set to true to use the module (default: false)
  "useModuleNotScript": $(if ($UseModuleNotScript) { 'true' } else { 'false' })
}
"@

        try {
            $configTemplate | Out-File -FilePath $configTemplatePath -Force -Encoding utf8
            Write-ModernStatus -Message "Configuration template saved: $configTemplatePath" -Status "success" -Indent 2
            Write-ModernStatus -Message "Rerun with: Install-EpacHydration -ConfigFile '$configTemplatePath' -NonInteractive" -Status "info" -Indent 2
        }
        catch {
            Write-ModernStatus -Message "Failed to save configuration template: $_" -Status "warning" -Indent 2
        }

        return @{
            Success            = $true
            Configuration      = $epacConfig
            ConfigTemplatePath = $configTemplatePath
        }
    }
    catch {
        Write-Error "Installation failed: $_"
        Write-ModernStatus -Message "Error details logged to: $OutputFolder/Logs/epac-hydration.log" -Status "error" -Indent 2
        return @{
            Success = $false
            Error   = $_
        }
    }
}
