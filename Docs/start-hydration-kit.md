# EPAC Hydration Kit

The EPAC Hydration Kit is an interactive installer designed to accelerate onboarding of EPAC as a policy management solution. It automates the initial setup process and guides you through key configuration decisions.

**What you'll get:** A foundational EPAC implementation with starter policies & CI/CD pipelines.

The `Install-HydrationEpac` command builds a basic EPAC implementation for local testing and provides the foundation for CI/CD deployment through starter pipelines.

## Prerequisites

- Review the [Start Implementing](./start-implementing.md) to ensure you are familiar with the core EPAC concepts, have the prerequisite software installed and have the required Azure permissions.
- To run the Hydration Kit, permissions to create Management Groups at the **Tenant Root Level** is also required.
    - The `Management Group Contributor` built-in RBAC role contains the required permissions.
    - The Hydration Kit creates additional Management Groups for EPAC development.

### Before You Begin
1. **Connect to Azure:** Use `Connect-AzAccount` to authenticate to your Azure tenant
1. **Verify permissions:** Confirm you can create Management Groups at the tenant root level
1. **Choose your location:** Decide where you want the EPAC files to be created locally

## What the Hydration Kit Provides

The Hydration Kit guides you through the initial setup process for EPAC. Here's what it accomplishes:

1. **Creates folder structure:** Creates the `Definitions` directory with proper files & folders
1. **Configures settings:** Pre-Populates the `Global-Settings.jsonc` file
1. **Builds Management Groups:** 
    1. Creates an isolated `epac-dev` environment for safe testing
    1. Optionally deploys the recommended Cloud Adoption Framework v3 Management Group structure
1. **Imports existing policies:** Brings current Azure policies into EPAC for management
1. **Deploys compliance frameworks:** 
    1. Deploys the Microsoft Security Baseline (MSCB)
    1. Optionally deploys additional compliance policies (NIST, PCI-DSS, etc.)
7. **Provides CI/CD Starter Kit:** Generates starter pipelines for GitHub Actions or Azure DevOps

## Running the Hydration Kit Installer

### Prepare Your Environment

Set the location where you want EPAC files to be created. This could be a simple local directory, or a locally cloned repository.

```Powershell
$myRepoRoot = "/Path/To/Local/EPAC/Repo"
Set-Location $myRepoRoot
```

### Identify Your Tenant Intermediate Root

Determine the **Tenant Intermediate Root** Management Group ID. This will be set as the `deploymentRootScope` of the `tenant01` (main) `pacEnvironment`. This is typically your organization's top-level Management Group (e.g., "contoso"), **not** the Tenant Root Group.

### Run the Hydration Kit

Use the `Install-HydrationEpac` cmdlet to start the Hydration Kit Installer, specifying the `TenantIntermediateRoot`

```PowerShell
$tenantIntermediateRoot = "contoso" # Replace with your Management Group ID
Install-HydrationEpac -TenantIntermediateRoot $tenantIntermediateRoot
```

> [!IMPORTANT]
> If the Management Group specified as the `tenantIntermediateRoot` does not exist, the Hydration Kit will offer to create it. If you respond `no` the Hydration Kit will exit as a valid `deploymentRootScope` is required for the `tenant` (main) `pacEnvironment`.

> [!TIP]
> The installer creates an output file that you should keep for reuse, troubleshooting and reference. If errors occur, you can often resolve them and re-run the process.

### Key Decisions

The Hydration Kit will present you with a series of questions that will drive configuration that is specific to this implementation of EPAC:

#### Initial Configuration

1. **Confirm your Tenant ID** - Verify you're authenticated to the correct Azure tenant
1. **Set a PAC Owner ID** - Manually Specify a `pacOwnerId` or let the Hydration Kit auto-generate a GUID
1. **Implement CAFv3** - Decide whether to deploy the CAFv3 Management Group Structure within the specified `tenantIntermediateRoot`.
1. **Confirm provided scope** - Verify the `tenantIntermediateRoot` Management Group specified exists, and create one if not.

#### Cloud Adoption Framework (CAF) Naming
If you elect to deploy the CAFv3 Management Group structure, you will additionally be prompted for:

1. **Prefix for Management Groups** - (optional) Add a prefix to the CAFv3 Management Groups that will be created
1. **Suffix for Management Groups** - (optional) Add a suffix to the CAFv3 Management Groups that will be created

#### EPAC Environment Setup

1. **Main PacSelector** - Provide a symbolic `PacSelector` Name for the main EPAC Environment (`pacEnvironment`).
    - The `tenantIntermediateRoot` specified will be the `deploymentRootScope` for this `pacEnvironment`.
1. **epac-dev Parent** - Provide a Management Group that the `epac-dev` environment will be created. 
    - A copy of the `tenantIntermediateRoot` Management Group specified (and all its child Management Groups) will be created as a child of this management group.
1. **Managed Identity Location** - Choose a default Managed Identity Location for DeployIfNotExists and Modify Policies

#### epac-dev Naming

To support the `epac-dev` environment being deployed, a copy of the `tenantIntermediateRoot` Management Group (and all its child Management Groups) will be deployed. You have the option to:

1. **Prefix for Management Groups** - (optional) Add a prefix to the copied Management Groups that will be created for `epac-dev`
1. **Suffix for Management Groups** - (optional) Add a suffix to the  copied Management Groups that will be created for `epac-dev`

#### Policy Import and Compliance Frameworks

The Hydration Kit can help you get started with some initial policies, as well as import existing polices. You will be given the option to:

1. **Import Policies** - Import existing policies into EPAC - this will create the required EPAC files for managing these policies.
1. **Deploy Compliance Frameworks** - Add additional compliance frameworks to EPAC.
    - PCI-DSS compliance framework
    - NIST 800-53 v5 compliance framework.
    - Additional Built-In Policy Sets (specified via definition ID)

> [!NOTE]
> The Hydration Kit will always include a copy of The Microsoft Security Baseline (MSCB) to be deployed with EPAC.

> [!NOTE]
> While it is possible to both export policies from the management group structure and create it in the same step, it is rare that this is useful. Consider whether there is any content in this area to export when answering.

#### CI/CD Pipeline Configuration

EPAC supports various options for running EPAC through CI/CD pipelines. Choose the DevOps approach that best fits your existing toolsets:
1. **Execution method:** - Run EPAC via PowerShell Module (recommended) or source code
1. **Platform:** - Select starter pipelines built for GitHub Actions or Azure DevOps Pipelines

## Current Limitations

The Hydration Kit provides a working foundation but has some limitations that can be addressed manually after installation:

- **Multi-tenant scenarios:** Multiple Tenants cannot be automatically configured
- **Advanced branching flows:** Release Flow pacSelector cannot automatically be created

## Initial Test Deployment

Once the hydration kit is completed, you can test your deployment against the epac-dev Management Group hierarchy that was created as part of the deployment process.

```PowerShell
Build-DeploymentPlans  -PacEnvironmentSelector "epac-dev"
Deploy-PolicyPlan -PacEnvironmentSelector "epac-dev"
Deploy-RolesPlan -PacEnvironmentSelector "epac-dev"
```

## Next Steps

The installer builds out the repo insofar as CLI based deployment using a highly privileged account. After this prototype is complete, it is necessary to move to a more secure configuration that can be automated and audited.

- Review additional settings available for configuration in the [global-settings file](./settings-global-setting-file.md)
- Create additional policy objects such as custom policies, additional policy assignments, and exemptions. 
    1. Integrate [Azure Landing Zones (ALZ)](integrating-with-alz.md)
    1. Create custom [Policy definitions](policy-definitions.md)
    1. Create custom [Policy Set definitions](policy-set-definitions.md)
    1. Create new [Policy Assignments](policy-assignments.md)
    1. Manage [Policy Exemptions](policy-exemptions.md)
- [CI/CD Overview](ci-cd-overview.md) provides insight into how to continue with the configuration of your DevOps Platform for ongoing EPAC CI/CD deployment
- [Generate Documentation](./operational-scripts-documenting-policy.md) for Audit Purposes

## Upcoming Roadmap Items

### Install-HydrationEpac

1. Add Sync-AlzPolicies
1. Configure [Defender For Cloud Integration](./settings-dfc-assignments.md)
1. Generate Documentation for Compliance Assignments

### Additional Possible Future Installation Command Sets

Each of these sets is broken up by API usage to accomplish the task. As each will require a different framework, they are listed as separate initiatives.

1. Install-HydrationGithubRepo
    1. Configure GitHub repo/actions/environments/secrets/settings
        1. Release flow and configure pipeline moved to this process, kept basic flow until this process is ready
        1. Provide baseline security configuration
        1. Populate main branch
1. Install-HydrationAdoRepo
    1. Configure ADO repo/pipelines/environments/secrets/settings
        1. Flows: Release, Basic (GitHub), Exemption, Remediation
        1. Provide baseline security configuration
        1. Populate main branch

**The full list of available Hydration Kit commands can be retrieved by running the PowerShell below:**

```PowerShell
Get-Command -module EnterprisePolicyAsCode | Where-Object {$_.Name -like "*-Hydration*"}
```