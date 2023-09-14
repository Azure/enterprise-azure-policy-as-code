# Getting Started

## EPAC Quick Start

In this quick start you can get set up with EPAC and use it to extract the policies and assignments in your own environment. From that point you can either choose to let EPAC manage the policies or look at some of the more advanced features allowing you to complete a gradual rollout.

For this example all you need is ```Reader``` permission in your Azure environment and to follow the steps below.

1. [Install PowerShell 7](https://github.com/PowerShell/PowerShell/releases).
2. Install the Az PowerShell modules and connect to Azure.
```ps1
Install-Module Az -Scope CurrentUser
Connect-AzAccount
```
3. Install the Enterprise Policy as Code module.
```ps1
Install-Module EnterprisePolicyAsCode -Scope CurrentUser
```
4. Create a new EPAC definitions folder to hold policy objects.
```ps1
New-EPACDefinitionFolder -DefinitionsRootFolder Definitions
```
5. This will create a folder called ```Definitions``` with a number of subfolder and a ```global-settings.jsonc``` file where the environment is defined.
6. Edit the ```global-settings.jsonc``` file by copying the sample below. Modify the commented sections as appropriate.
```json
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json",
    "pacOwnerId": "f2ce1aea-944e-4517-94fb-edada00633ae", # Generate a guid using New-Guid and place it here
    "managedIdentityLocations": {
        "*": "australiaeast" # Update the default location for managed identities
    },
    "globalNotScopes": {
        "*": [
            "/resourceGroupPatterns/excluded-rg*"
        ]
    },
    "pacEnvironments": [
        {
            "pacSelector": "quick-start",
            "cloud": "AzureCloud",
            "tenantId": "bdb8ea1c-17da-4423-8895-6b79af002b4e", # Replace this with your tenant Id
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/root" # Replace this with a management group that represents the functional root in your environment. 
        }
    ]
}
```
7. Extract all the existing policies and assignments at the scope indicated above by running the script below.
```ps1
Export-AzPolicyResources -DefinitionsRootFolder .\Definitions -OutputFolder Output
```

In the ```Output``` folder you should now find all the custom policy definitions and assignments which have been deployed in your environment. From this point you can make some choices about how to best utilize EPAC to handle Azure Policy in your environment including:-

- Copy the Output files into the appropriate folders in your ```Definitions``` folder and use the ```Build-DeploymentPlans``` command to generate a plan for policy deployment. Once the plan is generated you can use the ```Deploy-PolicyPlan``` and ```Deploy-RolesPlan``` commands to start managing deployed policies with EPAC.
- Read up on [Desired State Strategy](desired-state-strategy.md) and plan a gradual rollout of policy using EPAC.
- Use the artifacts in the [Starter Kit](https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit) for some in-depth examples and sample pipelines for CI/CD integration. 
- Review the rest of this documentation to examine some of the more complex EPAC features.

If there are any issue please raise them in the (GitHub Repository)[https://github.com/Azure/enterprise-azure-policy-as-code/issues].

## Create your environment

* [Setup DevOps Environment](operating-environment.md) for your developers (on their workstations) and your CI/CD pipeline runners/agents (on a VM or set of VMs) to facilitate correct implementations. <br/> **Operating Environment Prerequisites:** The EPAC Deployment process is designed for DevOps CI/CD. It requires the installation of several tools to facilitate effective development, testing, and deployment during the course of a successful implementation.
* Acquire the PowerShell scripts (options)
  * [Import Azure PowerShell Module](powershell-module.md)
  * [Create a source repository and import the source code](clone-github.md) from this repository.

## Define your deployment scenarios

* [Select the desired state strategy](desired-state-strategy.md).
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.

## Create the CI/CD (skip if using the semi-automated approach)

* Copy starter kit pipeline definition and definition folder to your folders.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.

## Build your definitions and assignments

* Generate a starting point for the `Definitions` subfolders:
  * [Extract existing Policy resources from an environment](extract-existing-policy-resources.md).
  * [Import Policies from the Cloud Adoption Framework](integrating-with-alz.md).
  * Use the sample Policy resource definitions in the starter kit.
  * Start from scratch.
* [Add custom Policies](policy-definitions.md).
* [Add custom Policy Sets](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).

## Manage your Policy environment

* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](operational-scripts.md).

## Debug EPAC issues

Should you encounter issues with the expected behavior of EPAC, try the following:

* Run the scripts interactively.
* [Debug the scripts in VS Code](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/using-vscode?view=powershell-7.3).
* Ask for help by raising a [GitHub Issue](https://github.com/Azure/enterprise-azure-policy-as-code/issues/new)
