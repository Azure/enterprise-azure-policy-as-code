# Hydration Kit V2

The EPAC Hydration Kit V2 is a streamlined installation tool that simplifies the initial setup of Enterprise Policy as Code (EPAC) in your Azure environment. It provides smart defaults, optional enhancements, and a modern, user-friendly experience.

## Overview

The Hydration Kit V2 reduces complexity and setup time by:

- **Smart Defaults**: Sensible defaults for common configurations
- **Modern Output**: Clear, colorful progress indicators and status messages
- **Flexible Configuration**: Support for configuration files, CLI parameters, or interactive prompts
- **Iterative Enhancement**: Start simple, then add features by updating the config file and rerunning
- **Optional Enhancements**: Add features like dev environments and pipelines only when needed
- **Policy Import**: Import existing policy assignments from your current environment
- **Pipeline Integration**: Generate GitHub Actions or Azure DevOps pipelines with StarterKit templates

## Key Features

### Configuration Options

The Hydration Kit supports three ways to provide configuration:

1. **Configuration File**: Use `epac-hydration-config.jsonc` for repeatable deployments
2. **Command Line Parameters**: Override config file or provide values directly
3. **Interactive Prompts**: Guided prompts for missing required values

### Management Group Strategy

The V2 approach assumes your core Management Group structure already exists:

- **Verifies** the intermediate root Management Group (does not create)
- **Optionally creates** an `epac-dev` Management Group for safe policy testing
- **Generates** a configuration file (`epac-hydration-config.jsonc`) for easy feature addition

### Pipeline Support

Choose your DevOps platform and deployment style:

- **None**: Skip pipeline creation (default)
- **GitHub Actions**: Generate `.github/workflows/` with GitHub-specific triggers
- **Azure DevOps**: Generate `Pipelines/` with Azure DevOps YAML

Select between:

- **Simple**: Basic pipeline templates for quick start
- **StarterKit**: Full-featured templates cloned from the EPAC repository

Choose your branching strategy:

- **GitHub Flow**: Single main branch with feature branches
- **Release Flow**: Separate development and release branches

## Prerequisites

Before running the Hydration Kit, ensure you have:

1. **PowerShell 7.0+** installed
2. **Azure PowerShell modules**:
   - `Az.Accounts`
   - `Az.Resources`
3. **Appropriate Azure permissions**:
   - Management Group Contributor or Owner at the target scope
   - Permissions to create Managed Identities and Role Assignments
4. **Git** (if using pipeline generation)
5. **EPAC Module or Scripts** installed

## Parameters

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `TenantIntermediateRoot` | Management Group ID serving as organizational root | `"contoso"` |

### Core Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PacSelector` | `"tenant"` | Friendly name for EPAC environment |
| `ManagedIdentityLocation` | Prompted | Azure region for Managed Identities |
| `DefinitionsRootFolder` | `"./Definitions"` | Path to Policy Definitions folder |
| `OutputFolder` | `"./Output"` | Path to EPAC Output folder |

### Optional Enhancement Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `CreateDevEnvironment` | `$false` | Create separate `epac-dev` environment for testing |
| `ImportExistingPolicies` | `$false` | Import current policy assignments |
| `PipelinePlatform` | `"None"` | DevOps platform: `GitHub`, `AzureDevOps`, or `None` |
| `PipelineType` | `"Simple"` | Pipeline style: `Simple` or `StarterKit` |
| `BranchingFlow` | `"GitHub"` | Branching strategy: `GitHub` or `Release` |

### Automation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `UseModuleNotScript` | `$false` | Use PowerShell module instead of local scripts |
| `NonInteractive` | `$false` | Run without prompts (requires config file or all params) |
| `ConfigFile` | `null` | Path to configuration file (JSON/JSONC) |

## Configuration File

Create an `epac-hydration-config.jsonc` file for repeatable deployments:

```jsonc
{
  // Core Configuration
  "tenantIntermediateRoot": "contoso",
  "pacSelector": "tenant",
  "managedIdentityLocation": "eastus",
  
  // Folder Paths
  "definitionsRootFolder": "./Definitions",
  "outputFolder": "./Output",
  
  // Optional Enhancements
  "createDevEnvironment": false,  // Set to true to create epac-dev MG for testing
  "importExistingPolicies": false,
  
  // Pipeline Configuration
  // Set to 'None' to skip pipeline creation
  "pipelinePlatform": "None",     // Options: "None", "GitHub", "AzureDevOps"
  
  // Only applies when pipelinePlatform is "GitHub" or "AzureDevOps"
  "pipelineType": "Simple",       // Options: "Simple", "StarterKit"
  
  // Only applies when pipelineType is "StarterKit"
  "branchingFlow": "GitHub",      // Options: "GitHub", "Release"
  
  // Automation
  "useModuleNotScript": false,
  "nonInteractive": false
}
```

**Note:** After your first run, the Hydration Kit automatically generates this configuration file at `Output/epac-hydration-config.jsonc` with your current settings, making it easy to add features iteratively.

## Iterative Workflow

The Hydration Kit V2 encourages an iterative approach:

### Start Simple
```powershell
# Initial minimal setup
Install-EpacHydration -TenantIntermediateRoot "contoso"
```

**Result:** 
- Basic EPAC structure created
- Configuration saved to `Output/epac-hydration-config.jsonc`
- Next steps displayed with instructions for adding features

### Add Features Incrementally

The Hydration Kit shows you exactly which features can be added and how to enable them.

**Example output after initial run:**
```
╔════════════════════════════════════════════════════════════════════════╗
║                    Installation Complete!                              ║
╚════════════════════════════════════════════════════════════════════════╝

Next Steps
────────────────────────────────────────────────────────────────────────
1. Review generated files:
     Definitions folder: ./Definitions
     Global settings: ./Definitions/global-settings.jsonc

2. Build and deploy policies:
     Build-DeploymentPlans -PacEnvironmentSelector tenant
     Deploy-PolicyPlan -PacEnvironmentSelector tenant

Add Optional Features
────────────────────────────────────────────────────────────────────────
Configuration file saved: ./Output/epac-hydration-config.jsonc
To add features, edit the config file and rerun the hydration:

→ Add Dev Environment for testing:
    Set 'createDevEnvironment': true in ./Output/epac-hydration-config.jsonc

→ Import existing policies:
    Set 'importExistingPolicies': true in ./Output/epac-hydration-config.jsonc

→ Add CI/CD pipelines:
    Set 'pipelinePlatform': 'GitHub' or 'AzureDevOps' in ./Output/epac-hydration-config.jsonc
    Set 'pipelineType': 'Simple' or 'StarterKit' in ./Output/epac-hydration-config.jsonc

Then rerun: Install-EpacHydration -ConfigFile './Output/epac-hydration-config.jsonc' -NonInteractive
```

### Step-by-Step Enhancement Example

**Step 1: Initial Setup**
```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso"
```
Result: Basic structure created, config file generated.

**Step 2: Add Dev Environment**

Edit `Output/epac-hydration-config.jsonc`:
```jsonc
{
  "tenantIntermediateRoot": "contoso",
  "createDevEnvironment": true,  // Changed from false
  // ... other settings
}
```

Rerun:
```powershell
Install-EpacHydration -ConfigFile ./Output/epac-hydration-config.jsonc -NonInteractive
```
Result: Dev Management Group created, global-settings.jsonc updated with epac-dev environment.

**Step 3: Add Pipelines**

Edit `Output/epac-hydration-config.jsonc`:
```jsonc
{
  "tenantIntermediateRoot": "contoso",
  "createDevEnvironment": true,
  "pipelinePlatform": "GitHub",     // Changed from "None"
  "pipelineType": "StarterKit",     // Selected StarterKit
  // ... other settings
}
```

Rerun:
```powershell
Install-EpacHydration -ConfigFile ./Output/epac-hydration-config.jsonc -NonInteractive
```
Result: GitHub Actions workflows created with StarterKit templates.

**Benefits of Iterative Approach:**
- Start quickly without being overwhelmed
- Test basic functionality first
- Add complexity only when needed
- Configuration file serves as documentation
- Easy to replicate across environments

## Usage Examples

### Example 1: Minimal Setup

The simplest installation with interactive prompts:

```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso"
```

**What happens:**
- Verifies "contoso" Management Group exists
- Prompts for Managed Identity location
- Creates basic Definitions structure with single "tenant" environment
- No dev environment, no policy import, no pipelines

**Output:**
```
╔════════════════════════════════════════════════════════════════════════╗
║           EPAC Hydration Kit - Environment Setup                      ║
╚════════════════════════════════════════════════════════════════════════╝

📋 Configuration Summary
────────────────────────────────────────────────────────────────────────
  Tenant Root:           contoso
  PAC Selector:          tenant
  Dev Environment:       No
  Import Policies:       No
  Pipeline Platform:     None
────────────────────────────────────────────────────────────────────────

[Step 1/5] Checking Prerequisites
✓ Azure PowerShell module found
✓ Connected to Azure
✓ Permissions verified

[Step 2/5] Processing Configuration
✓ Configuration loaded

[Step 3/5] Verifying Management Group Structure
✓ Management Group 'contoso' exists
✓ Management Group structure verified

[Step 4/5] Initializing Repository Structure
✓ Definitions folder created
✓ Global settings configured
✓ Repository initialized

[Step 5/5] Optional Enhancements
ℹ No optional enhancements requested

╔════════════════════════════════════════════════════════════════════════╗
║                    Installation Complete!                              ║
╚════════════════════════════════════════════════════════════════════════╝

Configuration Summary
────────────────────────────────────────────────────────────────────────
  Tenant:                <tenant-id>
  Root MG:               contoso
  PacSelector:           tenant
  Definitions:           ./Definitions
  Output:                ./Output

Next Steps
────────────────────────────────────────────────────────────────────────
1. Review generated files:
     Definitions folder: ./Definitions
     Global settings: ./Definitions/global-settings.jsonc

2. Build and deploy policies:
     Build-DeploymentPlans -PacEnvironmentSelector tenant
     Deploy-PolicyPlan -PacEnvironmentSelector tenant

Add Optional Features
────────────────────────────────────────────────────────────────────────
Configuration file saved: ./Output/epac-hydration-config.jsonc
To add features, edit the config file and rerun the hydration:

→ Add Dev Environment for testing:
    Set 'createDevEnvironment': true in ./Output/epac-hydration-config.jsonc

→ Import existing policies:
    Set 'importExistingPolicies': true in ./Output/epac-hydration-config.jsonc

→ Add CI/CD pipelines:
    Set 'pipelinePlatform': 'GitHub' or 'AzureDevOps' in ./Output/epac-hydration-config.jsonc
    Set 'pipelineType': 'Simple' or 'StarterKit' in ./Output/epac-hydration-config.jsonc

Then rerun: Install-EpacHydration -ConfigFile './Output/epac-hydration-config.jsonc' -NonInteractive

  Documentation: https://aka.ms/epac
```

**Next steps shown:**
The output provides clear instructions on how to add features by editing the generated config file and rerunning the hydration.

### Example 2: Setup with Dev Environment

Create a safe testing environment alongside production:

```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso" -CreateDevEnvironment
```

**What happens:**
- Verifies "contoso" Management Group exists
- Creates new "epac-dev" Management Group under root
- Configures two pacEnvironments in `global-settings.jsonc`:
  - `tenant` → contoso (production)
  - `epac-dev` → epac-dev (testing)
- Allows safe policy testing before production deployment

**Use case:** Test policy changes in epac-dev, then promote to tenant environment.

### Example 3: Import Existing Policies

Import your current policy assignments to transition to EPAC:

```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso" -ImportExistingPolicies
```

**What happens:**
- Verifies Management Group structure
- Creates repository structure
- Exports existing policy assignments to timestamped folder
- Displays import statistics (assignments, parameters, identities)

**Output includes:**
```
[Step 5/5] Optional Enhancements
→ Importing existing policies from 'contoso'...

📊 Import Summary
────────────────────────────────────────────────────────────────────────
  Total Assignments:     42
  With Parameters:       28
  With Identities:       15
  Export Location:       ./Output/export-2024-01-15-143022
────────────────────────────────────────────────────────────────────────
✓ Policy import completed
```

### Example 4: GitHub Actions with Simple Pipelines

Generate basic GitHub Actions workflows:

```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso" `
    -PipelinePlatform GitHub `
    -PipelineType Simple
```

**What happens:**
- Creates `.github/workflows/` directory
- Generates simple pipeline YAML files
- Configures GitHub-specific triggers and actions

**Generated files:**
- `.github/workflows/epac-dev.yml` (if dev environment exists)
- `.github/workflows/epac-tenant.yml`

### Example 5: Azure DevOps with StarterKit Pipelines

Generate full-featured Azure DevOps pipelines using StarterKit templates:

```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso" `
    -PipelinePlatform AzureDevOps `
    -PipelineType StarterKit `
    -BranchingFlow Release
```

**What happens:**
- Clones EPAC repository to temporary location
- Imports StarterKit pipeline generation functions
- Creates `Pipelines/` directory
- Generates comprehensive Azure DevOps YAML with:
  - Build validation
  - Deployment stages
  - Manual approval gates
  - Release Flow branching strategy

**Generated structure:**
```
Pipelines/
  ├── epac-build-validation.yml
  ├── epac-deploy-tenant.yml
  └── epac-deploy-dev.yml (if CreateDevEnvironment)
```

### Example 6: Complete Setup with All Features

Full setup with dev environment, policy import, and StarterKit pipelines:

```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso" `
    -CreateDevEnvironment `
    -ImportExistingPolicies `
    -PipelinePlatform GitHub `
    -PipelineType StarterKit `
    -BranchingFlow Release
```

**What happens:**
- Verifies "contoso" Management Group
- Creates "epac-dev" Management Group
- Imports existing policies with statistics
- Clones EPAC repo and generates StarterKit GitHub Actions
- Configures Release Flow branching

**Resulting environment:**
```
Repository Structure:
├── .github/workflows/          # GitHub Actions pipelines
├── Definitions/                # Policy definitions
│   ├── global-settings.jsonc
│   ├── policyAssignments/
│   ├── policyDefinitions/
│   └── policySetDefinitions/
├── Output/                     # EPAC outputs
│   └── export-TIMESTAMP/       # Imported policies
└── Scripts/                    # EPAC scripts

Azure Structure:
Tenant Root
├── contoso (prod)              # Production environment
└── epac-dev                    # Testing environment
```

### Example 7: Configuration File Based Setup

Use a configuration file for repeatable, automated deployments:

**epac-config.jsonc:**
```jsonc
{
  "tenantIntermediateRoot": "contoso",
  "pacSelector": "tenant",
  "managedIdentityLocation": "eastus",
  "createDevEnvironment": true,
  "importExistingPolicies": true,
  "pipelinePlatform": "GitHub",
  "pipelineType": "StarterKit",
  "branchingFlow": "GitHub",
  "nonInteractive": true
}
```

**Command:**
```powershell
Install-EpacHydration -ConfigFile .\epac-config.jsonc
```

**Benefits:**
- Repeatable deployments across environments
- Version control your hydration configuration
- Automated CI/CD friendly
- No interactive prompts in automated scenarios

## Workflow Steps

The Hydration Kit executes in five distinct steps:

### Step 1: Prerequisites Check
- Verifies Azure PowerShell modules
- Checks Azure connection
- Validates permissions at target scope

### Step 2: Configuration Processing
- Loads configuration file (if provided)
- Merges with CLI parameters
- Prompts for missing required values
- Displays configuration summary

### Step 3: Management Group Verification
- **Verifies** intermediate root Management Group exists (errors if not found)
- **Creates** epac-dev Management Group (only if `-CreateDevEnvironment` specified)
- Does NOT create the intermediate root (assumes existing structure)

### Step 4: Repository Initialization
- Creates Definitions folder structure:
  - `policyAssignments/`
  - `policyDefinitions/`
  - `policySetDefinitions/`
- Generates `global-settings.jsonc` with:
  - Single `tenant` environment (default)
  - Additional `epac-dev` environment (if requested)
  - Managed Identity configuration
  - Default global settings

### Step 5: Optional Enhancements
- **Policy Import**: Exports existing assignments to timestamped folder
- **Pipeline Generation**: Creates platform-specific CI/CD pipelines

## Dev Environment Strategy

The `-CreateDevEnvironment` switch enables a safe testing workflow:

### Without Dev Environment (Default)
```
global-settings.jsonc:
{
  "pacEnvironments": [
    {
      "pacSelector": "tenant",
      "cloud": "AzureCloud",
      "tenantId": "<tenant-id>",
      "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/contoso"
    }
  ]
}
```

**Use case:** Simple deployments directly to production scope.

### With Dev Environment (`-CreateDevEnvironment`)
```
global-settings.jsonc:
{
  "pacEnvironments": [
    {
      "pacSelector": "tenant",
      "cloud": "AzureCloud",
      "tenantId": "<tenant-id>",
      "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/contoso"
    },
    {
      "pacSelector": "epac-dev",
      "cloud": "AzureCloud",
      "tenantId": "<tenant-id>",
      "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/epac-dev"
    }
  ]
}
```

**Use case:** Test policy changes safely:

1. Deploy to `epac-dev` environment first
2. Verify policies work as expected
3. Promote to `tenant` environment when confident

**Command examples:**
```powershell
# Test in dev
Build-DeploymentPlans -PacEnvironmentSelector epac-dev
Deploy-PolicyPlan -PacEnvironmentSelector epac-dev

# Deploy to production after validation
Build-DeploymentPlans -PacEnvironmentSelector tenant
Deploy-PolicyPlan -PacEnvironmentSelector tenant
```

## Pipeline Types

### None (Default)
No pipeline files generated. Manage deployments manually using PowerShell scripts.

**Best for:**
- Learning EPAC
- Small environments
- Manual deployment preference

### Simple Pipelines
Basic pipeline templates with essential stages.

**Generates:**
- Minimal YAML with build and deploy stages
- Basic triggers (push to main/master)
- Simple variable configuration

**Best for:**
- Quick CI/CD setup
- Teams new to pipelines
- Environments with custom pipeline requirements

### StarterKit Pipelines
Comprehensive, production-ready pipeline templates from the EPAC repository.

**Generates:**
- Multi-stage pipelines with approvals
- Branch policies and protection
- Environment-specific variables
- Build validation on pull requests
- Comprehensive logging and error handling

**Best for:**
- Enterprise deployments
- Teams following DevOps best practices
- Production-ready CI/CD requirements

## Branching Strategies

### GitHub Flow (Default)
Single-branch strategy with feature branches:

```
main
├── feature/new-policy-1
├── feature/update-assignments
└── feature/exemptions
```

**Workflow:**
1. Create feature branch from `main`
2. Make policy changes
3. Pull request triggers build validation
4. Merge to `main` triggers deployment

**Best for:**
- Continuous deployment
- Faster iteration cycles
- Simpler workflow

### Release Flow
Dual-branch strategy with development and release branches:

```
main (production)
└── develop
    ├── feature/new-policy-1
    ├── feature/update-assignments
    └── feature/exemptions
```

**Workflow:**
1. Create feature branch from `develop`
2. Make policy changes
3. Pull request to `develop` triggers build validation
4. Merge to `develop` triggers dev deployment
5. Pull request from `develop` to `main` triggers production deployment

**Best for:**
- Staged deployments
- Testing before production
- Enterprise approval processes

## Troubleshooting

### Management Group Not Found

**Error:**
```
✗ Management Group 'contoso' does not exist
```

**Solution:**
The Hydration Kit V2 verifies (not creates) the intermediate root. Ensure the Management Group exists before running:

```powershell
# Create the Management Group first
New-AzManagementGroup -GroupId "contoso" -DisplayName "Contoso"

# Then run Hydration Kit
Install-EpacHydration -TenantIntermediateRoot "contoso"
```

### Insufficient Permissions

**Error:**
```
✗ Insufficient permissions at scope '/providers/Microsoft.Management/managementGroups/contoso'
```

**Solution:**
Ensure your account has appropriate permissions:
- Management Group Contributor or Owner
- Permissions to create Managed Identities
- Permissions to assign roles

### Pipeline Creation Fails

**Error:**
```
✗ Failed to clone EPAC repository for StarterKit templates
```

**Solution:**
- Ensure Git is installed and in PATH
- Check network connectivity to GitHub
- Try with `-PipelineType Simple` as fallback

### Config File Not Loading

**Error:**
```
⚠ Configuration file not found: .\epac-config.jsonc
```

**Solution:**
- Verify file path is correct (absolute or relative)
- Ensure file has valid JSON/JSONC syntax
- Check file encoding (UTF-8 recommended)

## Best Practices

### 1. Start Simple, Add Features Iteratively
Begin with minimal setup, then add features using the generated config file:
```powershell
# First run: Basic setup
Install-EpacHydration -TenantIntermediateRoot "contoso"

# Review the generated config file
# Output/epac-hydration-config.jsonc

# Add dev environment by editing config:
# Set "createDevEnvironment": true

# Rerun with updated config
Install-EpacHydration -ConfigFile ./Output/epac-hydration-config.jsonc -NonInteractive

# Add pipelines by editing config:
# Set "pipelinePlatform": "GitHub"
# Set "pipelineType": "StarterKit"

# Rerun again with updated config
Install-EpacHydration -ConfigFile ./Output/epac-hydration-config.jsonc -NonInteractive
```

### 2. Use Configuration Files
Store configuration in version control for repeatability:
```powershell
# Commit epac-hydration-config.jsonc to repo
git add epac-hydration-config.jsonc
git commit -m "Add EPAC hydration configuration"

# Deploy consistently across environments
Install-EpacHydration -ConfigFile .\epac-hydration-config.jsonc -NonInteractive
```

### 3. Test in Dev First
Always use `-CreateDevEnvironment` for production scenarios:
```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso" -CreateDevEnvironment

# Test changes in dev
Build-DeploymentPlans -PacEnvironmentSelector epac-dev
Deploy-PolicyPlan -PacEnvironmentSelector epac-dev

# Verify results
Build-DeploymentPlans -PacEnvironmentSelector epac-dev -Output "table"

# Promote to production when confident
Build-DeploymentPlans -PacEnvironmentSelector tenant
Deploy-PolicyPlan -PacEnvironmentSelector tenant
```

### 4. Import Before Migrating
Use `-ImportExistingPolicies` to understand current state:
```powershell
Install-EpacHydration -TenantIntermediateRoot "contoso" -ImportExistingPolicies

# Review exported policies in Output/export-TIMESTAMP/
# Use as reference when creating EPAC definitions
```

### 5. Choose Appropriate Pipeline Type
- **None**: Learning, small environments
- **Simple**: Quick setup, custom requirements
- **StarterKit**: Enterprise, production-ready

### 6. Match Branching to Process
- **GitHub Flow**: Continuous deployment, agile teams
- **Release Flow**: Staged deployments, approval processes

## Next Steps

After running the Hydration Kit:

1. **Review Generated Files**
   - Check `Definitions/global-settings.jsonc`
   - Review folder structure
   - Review `Output/epac-hydration-config.jsonc` (your reusable configuration)
   - Examine pipeline files (if generated)
   - Review exported policies (if imported)

2. **Add Optional Features** (if not already configured)
   
   The Hydration Kit generates a configuration file at `Output/epac-hydration-config.jsonc` with your current settings.
   
   To add features, edit this file and rerun:
   
   **Add Dev Environment:**
   ```jsonc
   "createDevEnvironment": true
   ```
   
   **Import Existing Policies:**
   ```jsonc
   "importExistingPolicies": true
   ```
   
   **Add Pipelines:**
   ```jsonc
   "pipelinePlatform": "GitHub",  // or "AzureDevOps"
   "pipelineType": "StarterKit"    // or "Simple"
   ```
   
   Then rerun:
   ```powershell
   Install-EpacHydration -ConfigFile ./Output/epac-hydration-config.jsonc -NonInteractive
   ```

3. **Define Policies**
   - Add policy definitions to `Definitions/policyDefinitions/`
   - Add policy sets to `Definitions/policySetDefinitions/`
   - Add policy assignments to `Definitions/policyAssignments/`
   - See [Policy Definitions](policy-definitions.md) for details

4. **Build and Test Deployment Plans**
   
   If you created a dev environment:
   ```powershell
   # Test in dev first
   Build-DeploymentPlans -PacEnvironmentSelector epac-dev
   Deploy-PolicyPlan -PacEnvironmentSelector epac-dev
   
   # Then deploy to production
   Build-DeploymentPlans -PacEnvironmentSelector tenant
   Deploy-PolicyPlan -PacEnvironmentSelector tenant
   ```
   
   If no dev environment:
   ```powershell
   Build-DeploymentPlans -PacEnvironmentSelector tenant
   Deploy-PolicyPlan -PacEnvironmentSelector tenant
   ```

5. **Set Up CI/CD** (if pipelines generated)
   - Configure service connections / service principals
   - Set up repository secrets / variables
   - Enable pipeline triggers

6. **Iterate and Enhance**
   - Add more policy definitions
   - Configure exemptions
   - Set up monitoring and reporting

## Related Documentation

- [EPAC Overview](index.md)
- [Manual Configuration](manual-configuration.md)
- [Global Settings](settings-global-setting-file.md)
- [Policy Definitions](policy-definitions.md)
- [Policy Assignments](policy-assignments.md)
- [CI/CD Overview](ci-cd-overview.md)
- [GitHub Actions](ci-cd-github-actions.md)
- [Azure DevOps Pipelines](ci-cd-ado-pipelines.md)

## Support

For issues, questions, or contributions:

- **Documentation**: [https://aka.ms/epac](https://aka.ms/epac)
- **GitHub Repository**: [https://github.com/Azure/enterprise-azure-policy-as-code](https://github.com/Azure/enterprise-azure-policy-as-code)
- **Issues**: [GitHub Issues](https://github.com/Azure/enterprise-azure-policy-as-code/issues)
