# CI/CD Overview

Since EPAC is based on PowerShell scripts, any CI/CD tool with the ability to execute scripts can be used. The starter kits currently include pipeline definitions for Azure DevOps and GitHub Actions. Additional starter kits are being implemented and will be added in future releases.

The authors are interested in supporting other deployment pipelines. If you have developed pipelines for other technologies, such as GitLab, Jenkins, etc., please contribute them to the project as additional starter kits.

This repository contains starter pipelines and instructions for can be found here:

- [Azure DevOps Pipelines](ci-cd-ado-pipelines.md)
- [GitHub Actions](ci-cd-github-actions.md)

## General EPAC Deployment Steps

EPAC has three major steps in the Deployment process for each environment.
- Build Deployment Plans
- Policy Deployment
- Role Deployment

Each step can be called by using the `EnterprisePolicyAsCode` PowerShell module (recommended), or calling the script directly. For more details on EPAC installation options, please refer to the [Start Implementation](start-implementing.md/#install-powershell-and-epac) section.

> [!TIP]
> EPAC is **declarative** and **idempotent**: this means, that regardless how many times it is run, EPAC will always push all changes that were implemented in the JSON files to the Azure environment, i.e. if a JSON file is newly created/updated/deleted, EPAC will create/update/delete the Policy and/or Policy Set and/or Policy Assignments definition in Azure. If there are no changes, EPAC can be run any number of times, as it won't make any changes to Azure.

### Build Deployment Plans
Analyzes changes in Policy definition, Policy Set definition, Policy Assignment & Policy Exemption files for a given environment. It calculates and displays any deltas, while creating the deployment plan(s) to apply any changes. A "Policy Plan" will be created for use by the Policy Deployment step if any changes are found to the policy objects, assignments, or exemptions while a "Role Plan" will be created for use by the Role deployment step should there be any changes to role assignments for the deployed policies. If no changes are found, no plans are created.

For saving the output related to ```Build-DeploymentPlans``` there is global variable called ```$epacInfoStream``` which captures all output from the commands. If required, this can be used as a PR message or to present a summary of the plan.

**Deployment Mechanism**

|Deployment Mode | Command/Script |
|----------|-------------|
| Module (Recommended) | Build-DeploymentPlans |
| Script | Build-DeploymentPlans.ps1 | 

**Parameters**

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Selects the EPAC environment for this plan. If omitted, interactively prompts for the value. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It must contain the file `global-settings.jsonc`. |
| `Interactive` | Defaults to `$false`. |
| `OutputFolder` | Output folder path for plan files. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Output`. |
| `DevOpsType` | If set, outputs variables consumable by conditions in a DevOps pipeline. Default: not set. |
| `BuildExemptionsOnly` | If set, only builds the Exemptions plan. This useful to fast-track Exemption when utilizing [Release Flow](#advanced-cicd-with-release-flow) Default: not set. |

### Policy Deployment
Deploys Policies, Policy Sets, Policy Assignments, and Policy Exemptions at their desired scope based on the plan.

**Deployment Mechanism**

|Deployment Mode | Command/Script |
|----------|-------------|
| Module (Recommended) | Deploy-PolicyPlan |
| Script | Deploy-PolicyPlan.ps1 | 

**Parameters**

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Selects the EPAC environment for this plan. If omitted, interactively prompts for the value. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It must contain the file `global-settings.jsonc`. |
| `Interactive` | Defaults to `$false`. |
| `InputFolder` | Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER`, `$env:PAC_OUTPUT_FOLDER` or `./Output`. |

### Role Deployment
Creates the role assignments for the Managed Identities required for `DeployIfNotExists` and `Modify` Policies.

**Deployment Mechanism**

|Deployment Mode | Command/Script |
|----------|-------------|
| Module (Recommended) | Deploy-RolesPlan |
| Script | Deploy-RolesPlan.ps1 | 

**Parameters**

|Parameter | Explanation |
|----------|-------------|
| `PacEnvironmentSelector` | Selects the EPAC environment for this plan. If omitted, interactively prompts for the value. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It must contain the file `global-settings.jsonc`. |
| `Interactive` | Defaults to `$false`. |
| `InputFolder` | Input folder path for plan files. Defaults to environment variable `$env:PAC_INPUT_FOLDER`, `$env:PAC_OUTPUT_FOLDER` or `./Output`. |

## Create Azure DevOps Pipelines or GitHub Workflows from Starter Pipelines.

Starter Pipelines have been created to orchestrate the EPAC deployment steps listed above. The scripts `New-PipelinesFromStarterKit` create [Azure DevOps Pipelines or GitHub Workflows from the starter kit](operational-scripts-hydration-kit.md#create-azure-devops-pipeline-or-github-workflow). You select the type of pipeline to create, the branching flow to implement, and the ScriptType to use.
- The starter kits support two branching/release strategies (`GitHub` and `Release`). More details on these branching flows refer to the [Branching Flow Guidance](ci-cd-branching-flows.md).
- The recommended `ScriptType` is `module`, which utilizes the `EnterprisePolicyAsCode` Powershell module. For more details on EPAC installation options, please refer to the [Start Implementation](start-implementing.md/#install-powershell-and-epac) section.

### Azure DevOps Pipelines

The following commands create Azure DevOps Pipelines from the starter kit; use one of the commands:

```ps1
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\pipelines -PipelineType AzureDevOps -BranchingFlow GitHub -ScriptType script
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\pipelines -PipelineType AzureDevOps -BranchingFlow Release -ScriptType script
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\pipelines -PipelineType AzureDevOps -BranchingFlow GitHub -ScriptType module
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\pipelines -PipelineType AzureDevOps -BranchingFlow Release -ScriptType module
```

### GitHub Workflows

The following commands create GitHub Workflows from the starter kit; use one of the commands:

```ps1
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\.github/workflows -PipelineType GitHubActions -BranchingFlow GitHub -ScriptType script
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\.github/workflows -PipelineType GitHubActions -BranchingFlow Release -ScriptType script
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\.github/workflows -PipelineType GitHubActions -BranchingFlow GitHub -ScriptType module
New-PipelinesFromStarterKit -StarterKitFolder .\StarterKit -PipelinesFolder .\.github/workflows -PipelineType GitHubActions -BranchingFlow Release -ScriptType module
```

## General Hardening Guidelines

- **Least Privilege**: Use the least privilege principle when assigning roles to the SPNs used in the CI/CD pipeline. The roles should be assigned at the root or pseudo-root management group level. For more details on the SPNs to use and required permissions refer to [App Registrations Setup](ci-cd-app-registrations.md)
- Require a Pull Request for changes to the `main` branch. This ensures that changes are reviewed before deployment.
- Require additional reviewers for yml pipeline and script changes.
- Require branches to be in a folder `feature` to prevent accidental deployment of branches.
- Require an approval step between the Plan stage/job and the Deploy stage/job. This ensures that the changes are reviewed before deployment.
- [Optional] Require an approval step between the Deploy stage/job and the Role Assignments stage/job. This ensures that the role assignments are reviewed before deployment.
- For `Release Flow` only: allow only privileged users to create `releases-prod` and `releases-exemptions-only` branches and require those branches to be created from the main branch only.
