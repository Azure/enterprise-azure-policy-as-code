# Quick Start (Overview)

## Create your environment

* [Setup DevOps Environment](operating-environment.md) for your developers (on their workstations) and your CI/CD pipeline runners/agents (on a VM or set of VMs) to facilitate correct implementations. <br/> **Operating Environment Prerequisites:** The EPAC Deployment process is designed for DevOps CI/CD. It requires the [installation of several tools] to facilitate effective development, testing, and deployment during the course of a successful implementation.
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
