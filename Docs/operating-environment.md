# Operating Environment

**On this page**

* [EPAC Software Requirements](#epac-software-requirements)
  * [Pipeline Runner or Agent](#pipeline-runner-or-agent)
  * [Developer Workstation](#developer-workstation)
* [Required Management Groups and Subscriptions](#required-management-groups-and-subscriptions)
* [Security Considerations for DevOps CI/CD Runners/Agents](#security-considerations-for-devops-cicd-runnersagents)
* [Reading List](#reading-list)

## EPAC Software Requirements

Your operating environment will include two repos, a runner, and at least one developer machine. The following software is required on the runners and any developer workstation.

* PowerShell 7.3.1 or later, 7.3.2 (latest) recommended
* PowerShell Modules
  * Az required 9.3.0 or later - **9.2.x has a bug which causes EPAC to fail**
  * ImportExcel (required only if using Excel functionality)
* Git latest version

> Note: AzCli Module, Azure CLI, and Python are no longer required as of our v6.0 (January 2023) release.

### Pipeline Runner or Agent

OS: Any that Support PowerShell versions above.

* Linux and Windows are fully supported by EPAC
* Mac OS might work; however, we have not tested this scenario.

Software: Must Meet [EPAC Software Requirements](#epac-software-requirements).

### Developer Workstation

* Software: Must meet [EPAC Software Requirements](#epac-software-requirements).
* Software Recommendations: Visual Studio Code 1.74.3 or later (may work with older versions)

## Required Management Groups and Subscriptions

This solution requires EPAC environments for development, (optional) integration, and production per Azure tenant. These EPAC environments are not the same as the standard Azure environments for applications or solutions - do not confuse them; EPAC non-prod environment are only for development and integration of Azure Policy.  The standard Azure Sandbox, DEV, DEVINT, TEST/QA and PROD app solution environments are managed with Policy deployed from the EPAC PROD environment.

* Build a management group dedicated to Policy as Code (PaC) -- `mg-epac-dev` <br/> <https://docs.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal>
* Create management groups or subscriptions to simulate your EPAC production environments.

## Security Considerations for DevOps CI/CD Runners/Agents

Agents (also called runners) are often hosted in VMs within Azure itself. It is therefore essential to manage them as highly privileged devices.

> ---
> ---
>
> **Servers/VMs requirements:**
>
> * Utilize hardened images.
> * Be managed as high-privilege assets to minimize the risk of compromise.
> * Only used for a single purpose.
> * Hosted in PROD tenant in multi-tenant scenarios.
> * Hosted in the hub VNET or a shared services VNET.
>
> ---
> ---

<br/>

## Reading List

* [Setup DevOps Environment](operating-environment.md) .
* [Create a source repository and import the source code](clone-github.md) from this repository.
* [Select the desired state strategy](desired-state-strategy.md)
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.
* Optional: generate a starting point for the `Definitions` folders:
  * [Extract existing Policy resources from an environment](extract-existing-policy-resources.md).
  * [Import Policies from the Cloud Adoption Framework](cloud-adoption-framework.md).
* [Add custom Policies](policy-definitions.md).
* [Add custom Policy Sets](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).
* Import Policies from the [Cloud Adoption Framework](cloud-adoption-framework.md).
* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](operational-scripts.md).

**[Return to the main page](../README.md)**
