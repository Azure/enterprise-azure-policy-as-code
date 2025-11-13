# EPAC Hydration Kit V2 - Quick Start Guide

Get your EPAC environment running in under 5 minutes!

## Prerequisites (1 minute)

```powershell
# 1. Ensure you have PowerShell 7+ and Az modules
$PSVersionTable.PSVersion  # Should be 7.0+

# 2. Install Az modules if needed
Install-Module Az -Force

# 3. Connect to Azure
Connect-AzAccount

# 4. Verify connection
Get-AzContext
```

## Installation (3 minutes)

### Option 1: Minimal Interactive Setup

```powershell
# Navigate to your EPAC repository
cd C:\path\to\epac-repo

# Load V2 functions
. ./Scripts/HydrationKitV2/Load-Functions.ps1

# Run with minimum required parameter
# (Will prompt for Managed Identity location)
Install-EpacHydration -TenantIntermediateRoot "contoso"
```

**What this does:**
- ✓ Creates Management Group "contoso" (if it doesn't exist)
- ✓ Creates epac-dev environment for testing
- ✓ Generates Definitions folder structure
- ✓ Creates global-settings.jsonc with both environments
- ✓ Ready to deploy policies!

### Option 2: Fully Automated Setup

```powershell
# Load functions
. ./Scripts/HydrationKitV2/Load-Functions.ps1

# Run with all parameters (no prompts)
Install-EpacHydration `
    -TenantIntermediateRoot "contoso" `
    -ManagedIdentityLocation "eastus" `
    -NonInteractive
```

### Option 3: Full Featured Setup

```powershell
# Load functions
. ./Scripts/HydrationKitV2/Load-Functions.ps1

# Import existing policies and create GitHub pipeline
Install-EpacHydration `
    -TenantIntermediateRoot "contoso" `
    -ManagedIdentityLocation "eastus" `
    -ImportExistingPolicies `
    -PipelinePlatform GitHub `
    -UseModuleNotScript
```

### Option 4: Configuration File

```powershell
# 1. Create config file: my-epac-config.json
{
  "tenantIntermediateRoot": "contoso",
  "managedIdentityLocation": "eastus",
  "importExistingPolicies": true,
  "pipelinePlatform": "GitHub"
}

# 2. Load functions
. ./Scripts/HydrationKitV2/Load-Functions.ps1

# 3. Run with config
Install-EpacHydration -ConfigFile ./my-epac-config.json -NonInteractive
```

## What You Get

After installation, you'll have:

```
YourRepo/
├── Definitions/
│   ├── global-settings.jsonc          # Your EPAC environments
│   ├── README.md                      # Guide to your setup
│   ├── policyDefinitions/             # Custom policy definitions
│   ├── policySetDefinitions/          # Custom policy sets
│   ├── policyAssignments/             # Policy assignments
│   ├── policyExemptions/              # Policy exemptions
│   └── policyDocumentations/          # Documentation config
├── Output/
│   └── Logs/
│       └── epac-hydration-*.log       # Installation log
└── .github/workflows/                 # (if GitHub option selected)
    └── epac-deploy.yml                # CI/CD pipeline
```

## Testing Your Setup (1 minute)

```powershell
# Test deployment to epac-dev environment
Build-DeploymentPlans -PacEnvironmentSelector epac-dev

# Review the plan
Get-ChildItem ./Output/plans-epac-dev/

# Deploy to epac-dev
Deploy-PolicyPlan -PacEnvironmentSelector epac-dev
Deploy-RolesPlan -PacEnvironmentSelector epac-dev
```

## Common Scenarios

### Scenario 1: Brand New EPAC Setup
```powershell
. ./Scripts/HydrationKitV2/Load-Functions.ps1
Install-EpacHydration -TenantIntermediateRoot "contoso" -ManagedIdentityLocation "eastus"
```

### Scenario 2: Migrate Existing Policies to EPAC
```powershell
. ./Scripts/HydrationKitV2/Load-Functions.ps1
Install-EpacHydration `
    -TenantIntermediateRoot "contoso" `
    -ManagedIdentityLocation "eastus" `
    -ImportExistingPolicies
```

### Scenario 3: Setup with GitHub Actions
```powershell
. ./Scripts/HydrationKitV2/Load-Functions.ps1
Install-EpacHydration `
    -TenantIntermediateRoot "contoso" `
    -ManagedIdentityLocation "eastus" `
    -PipelinePlatform GitHub
```

### Scenario 4: Setup with Azure DevOps
```powershell
. ./Scripts/HydrationKitV2/Load-Functions.ps1
Install-EpacHydration `
    -TenantIntermediateRoot "contoso" `
    -ManagedIdentityLocation "eastus" `
    -PipelinePlatform AzureDevOps
```

### Scenario 5: CI/CD Automated Setup
```powershell
# In your build pipeline
. ./Scripts/HydrationKitV2/Load-Functions.ps1

Install-EpacHydration `
    -TenantIntermediateRoot $env:TENANT_ROOT `
    -ManagedIdentityLocation $env:AZURE_REGION `
    -NonInteractive
```

## Troubleshooting

### "Not connected to Azure"
**Solution:**
```powershell
Connect-AzAccount
# Or for service principal
Connect-AzAccount -ServicePrincipal -Tenant $tenantId -Credential $credential
```

### "Permission denied to create Management Group"
**Solution:**
You need the `Management Group Contributor` role at the Tenant Root level.
```powershell
# Check your permissions
Get-AzRoleAssignment | Where-Object {$_.RoleDefinitionName -like "*Management Group*"}
```

### "EPAC module commands not found"
**Solution:**
```powershell
Install-Module EnterprisePolicyAsCode -Force
Import-Module EnterprisePolicyAsCode
```

### "Management Group already exists"
**Solution:**
This is fine! The script will use the existing Management Group. If you see errors, it might be:
- Name collision with epac-dev prefix
- Permissions issue on existing MG

### "Can't write to Definitions folder"
**Solution:**
```powershell
# Make sure you're in the right directory
Get-Location

# Check write permissions
Test-Path ./Definitions -PathType Container
```

## Next Steps

1. **Review Generated Files**
   ```powershell
   Get-ChildItem ./Definitions -Recurse
   ```

2. **Customize Policy Assignments**
   - Edit files in `Definitions/policyAssignments/`
   - Add custom policies to `policyDefinitions/`

3. **Test in EPAC-Dev**
   ```powershell
   Build-DeploymentPlans -PacEnvironmentSelector epac-dev
   Deploy-PolicyPlan -PacEnvironmentSelector epac-dev
   ```

4. **Setup CI/CD**
   - Configure secrets in GitHub/Azure DevOps
   - Test pipeline execution
   - Enable branch protection

5. **Deploy to Production**
   ```powershell
   Build-DeploymentPlans -PacEnvironmentSelector tenant01
   Deploy-PolicyPlan -PacEnvironmentSelector tenant01
   Deploy-RolesPlan -PacEnvironmentSelector tenant01
   ```

## Advanced Usage

### Run Individual Components

```powershell
# Load functions
. ./Scripts/HydrationKitV2/Load-Functions.ps1

# Step 1: Build configuration only
$config = New-EpacConfiguration `
    -TenantIntermediateRoot "contoso" `
    -ManagedIdentityLocation "eastus" `
    -NonInteractive

# Step 2: Deploy Azure resources only
Deploy-EpacResources -Configuration $config

# Step 3: Initialize repository only
Initialize-EpacRepository -Configuration $config

# Step 4: Import policies separately
Import-EpacPolicies -Configuration $config

# Step 5: Create pipeline separately
New-EpacPipeline -Platform GitHub -Configuration $config
```

### Customize Configuration

```powershell
# Build base config
$config = New-EpacConfiguration -TenantIntermediateRoot "contoso" -NonInteractive

# Customize before deployment
$config.DesiredState = "full"                    # Change from "ownedOnly"
$config.EpacDevPrefix = "test-"                  # Custom prefix
$config.PacSelector = "production"               # Custom name

# Deploy with customizations
Initialize-EpacRepository -Configuration $config
```

## Getting Help

```powershell
# View help for main function
Get-Help Install-EpacHydration -Full

# View help for configuration builder
Get-Help New-EpacConfiguration -Full

# View all V2 functions
Get-Command -Module *Epac* | Where-Object {$_.Source -like "*V2*"}
```

## Comparison with V1

| Feature | V1 (Original) | V2 (Simplified) |
|---------|---------------|-----------------|
| Setup Time | 15-20 minutes | 2-3 minutes |
| Questions | 20+ prompts | 1-2 prompts |
| Required Inputs | Many | 1 (MG name) |
| Automation | Difficult | Easy |
| Config File | No | Yes |
| Modular | No | Yes |

## Resources

- **Full Documentation**: [README.md](./README.md)
- **Detailed Comparison**: [SIMPLIFICATION_SUMMARY.md](./SIMPLIFICATION_SUMMARY.md)
- **Config Template**: [epac-config.template.json](./epac-config.template.json)
- **EPAC Docs**: https://aka.ms/epac
- **GitHub**: https://github.com/Azure/enterprise-azure-policy-as-code

---

**Ready? Let's go!**

```powershell
. ./Scripts/HydrationKitV2/Load-Functions.ps1
Install-EpacHydration -TenantIntermediateRoot "YOUR-MG-NAME"
```
