# Manual Configuration Steps

This guide walks you through manually setting up EPAC when the Hydration Kit doesn't meet your specific requirements. 

**When to use Manual Configuration:**

- Complex multi-tenant scenarios
- Custom folder structures or naming conventions 
- Advanced customization requirements
- Specific compliance or organizational constraints

> [!TIP]
> **Consider the Hydration Kit first:** Even for advanced scenarios, you might start with the Hydration Kit and then customize the generated configuration. This can save time and provide a solid foundation. If they Hydration Kit is lacking on specific functionality that prevents its use in your environment, please **[Open a GitHub Issue](https://github.com/Azure/enterprise-azure-policy-as-code/issues)** to provide feedback and feature requests.

## Prerequisites

- Review the [Start Implementing](./start-implementing.md) to ensure you are familiar with the core EPAC concepts, have the prerequisite software installed and have the required Azure permissions.

## Manual Configuration Steps
### Prepare Your Environment

Set the location where you want EPAC files to be created. This could be a simple local directory, or a locally cloned repository.

```Powershell
$myRepoRoot = "/Path/To/Local/EPAC/Repo"
Set-Location $myRepoRoot
```

### Create the Definitions Root folder
Create a new EPAC `DefinitionsRootFolder` folder that contains the policy object subfolders and the `global-settings.jsonc` file. The `DefinitionsRootFolder` can have any name, however, we recommend `Definitions` and this is used through the documentation and starter kit.

#### Option A: Using EPAC PowerShell Module (Recommended)

```powershell
New-HydrationDefinitionsFolder -DefinitionsRootFolder "Definitions"
```
#### Option B: Manual Creation:

Create a `DefinitionsRootFolder` with your preferred name that contains the required subfolders and `global-settings.jsonc` file. For an example, please see [StarterKit/Definitions-Common](https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit/Definitions-Common).

### Set Up Management Groups for epac-dev

Create a development Management Group hierarchy separate from your main production hierarchy. This isolated environment allows you to safely test policy changes without affecting production workloads.

The development environment should mirror your production Management Group structure to provide representative testing. This typically involves creating a parallel hierarchy under a dedicated parent Management Group (e.g., "epac-contoso" as a copy of "contoso").

For additional information on `epac-dev`, review the [EPAC Environments Overview](./start-implementing.md#epac-environments-overview)

### Global Settings File

Populate `global-settings.jsonc` with your [environment settings](./settings-global-setting-file.md#Define-EPAC-Environments-in-`pacEnvironments`) and [desired state strategy](settings-dfc-assignments.md)

A sample `global-settings.jsonc` file is available as part of the [starter kit](https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit/Definitions-Common) with basic options defined.

### Populate Policy Definitions

#### Option A: Import Existing Policies

Extract [existing Policy resources](start-extracting-policy-resources.md) from your Azure environment.

#### Option B: Start with Sample Policies

Use the  [StarterKit](https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit/Definitions-GitHub-Flow) policies as an initial deployment.

#### Option C: Create Custom Policies Objects

Create custom [policy definitions](./policy-definitions.md), [policy set definitions](./policy-set-definitions.md) and/or [policy assignments](./policy-assignments.md) based on your organization's needs.

## Initial Test Deployment

You can test your deployment against the epac-dev Management Group hierarchy that was created as part of the deployment process.

```PowerShell
Build-DeploymentPlans  -PacEnvironmentSelector "epac-dev"
Deploy-PolicyPlan -PacEnvironmentSelector "epac-dev"
Deploy-RolesPlan -PacEnvironmentSelector "epac-dev"
```

> [!NOTE]
> Many scripts use parameters for input and output folders. They default to the current directory. We recommend that you do one of the following approaches instead of accepting the default to prevent your files being created in the wrong location:
>
>- [Preferred] Set the environment variables `PAC_DEFINITIONS_FOLDER`, `PAC_OUTPUT_FOLDER`, and `PAC_INPUT_FOLDER`.
>- [Alternative] Use the script parameters `-DefinitionsRootFolder`, `-OutputFolder`, and `-InputFolder`.

## Starter Kit Pipelines

Create a basic pipeline from the starter kit for CI/CD integration. For detailed pipeline configuration, review the [CI/CD Overview](ci-cd-overview.md).

### Using EPAC PowerShell Module (Recommended)

Run one of the following commands based on your pipeline tool of choice.
```powershell
### GitHub Actions
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\.github/workflows -PipelineType GitHubActions -BranchingFlow GitHub -ScriptType module

### Azure DevOps
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\pipelines -PipelineType AzureDevOps -BranchingFlow GitHub -ScriptType module
```

## Next Steps

You now have the working basics of an EPAC deployment running through the CLI. To continue to expand and further customize your EPAC deployment, review the following guidance:

- Review additional settings available for configuration in the [global-settings file](./settings-global-setting-file.md)
- Create additional policy objects such as custom policies, additional policy assignments, and exemptions. 
    1. Integrate [Azure Landing Zones (ALZ)](integrating-with-alz-library-overview.md)
    1. Create custom [Policy definitions](policy-definitions.md)
    1. Create custom [Policy Set definitions](policy-set-definitions.md)
    1. Create new [Policy Assignments](policy-assignments.md)
    1. Manage [Policy Exemptions](policy-exemptions.md)
- [CI/CD Overview](ci-cd-overview.md) provides insight into how to continue with the configuration of your DevOps Platform for ongoing EPAC CI/CD deployment, which is the next major area of focus.
- [Generate Documentation](./operational-scripts-documenting-policy.md) for Audit Purposes