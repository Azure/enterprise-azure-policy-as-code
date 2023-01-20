# Enterprise Azure Policy as Code V6.0

<br/>

> ---
> ---
>
> **Breaking changes in V6.0**
>
> A reorganization of the source code and adding a substantial feature enhancement required breaking changes to the folder structure, scripts, pipeline and global-settings.jsonc file.
>
> [Breaking change details and instructions on upgrading from a previous version](Docs/breaking-changes-v6.0.md).
>
> ---
> ---

<br/><br/>

**On this page**

* [Overview](#overview)
  * [Deployment Scripts](#deployment-scripts)
  * [CI/CD Tool Compatibility](#cicd-tool-compatibility)
  * [Multi-Tenant Support](#multi-tenant-support)
  * [Operational Scripts](#operational-scripts)
  * [Microsoft's Security \& Compliance for Cloud Infrastructure](#microsofts-security--compliance-for-cloud-infrastructure)
* [Understanding EPAC Environments and the pacSelector](#understanding-epac-environments-and-the-pacselector)
* [Approach Flexibility](#approach-flexibility)
  * [CI/CD Scenarios](#cicd-scenarios)
  * [Coexistence and Desired State Strategy](#coexistence-and-desired-state-strategy)
* [Quick Start](#quick-start)
  * [Create your environment](#create-your-environment)
  * [Define your deployment scenarios](#define-your-deployment-scenarios)
  * [Create the CI/CD (skip if using the semi-automated approach)](#create-the-cicd-skip-if-using-the-semi-automated-approach)
  * [Build your definitions and assignments](#build-your-definitions-and-assignments)
  * [Manage your Policy environment](#manage-your-policy-environment)
  * [Debug EPAC issues](#debug-epac-issues)
* [Contributing](#contributing)
* [Trademarks](#trademarks)

<br/>

## Overview

Enterprise Policy as Code or EPAC for short comprises a number of scripts which can be used in CI/CD based system or a semi-automated use to deploy Policy definitions, Policy Set (Initiative) definitions, Policy Assignments, Policy Exemptions and Policy Assignment related Role assignments.

### Deployment Scripts

Three deployment scripts plan a deployment, deploy Policy resource, and Role assignments respectively as shown in the following diagram. The solution consumes definition files (JSON and/or CSV files). The planning script (`Build-DeploymentPlan`) creates plan files (`policy-plan.json` and `roles-plan.json`) to be consumed by the two deployment steps (`Deploy-PolicyPlan` and `Deploy-RolesPlan`). The scripts require `Reader`, `Contributor` and `User Access Administrator` privileges respectively as indicated in blue text in the diagram. The diagram also shows the usual approval gates after each step/script for prod deployments.

![image.png](Docs/Images/epac-deployment-scripts.png)

<br/>

### CI/CD Tool Compatibility

Since EPAC is based on PowerShell scripts, any CI/CD tool with the ability to execute scripts can be used. The starter kits currently include pipeline definitions for Azure DevOps. Additional starter kits are being implemented and will be added in future releases.

### Multi-Tenant Support

EPAC supports single and multi-tenant deployments from a single source. In most cases you should have a fully or partially isolated area for Policy development and testing, such as a Management Group. An entire tenant can be used; however, it is not necessary since EPAC has sophisticated partitioning capabilities.

### Operational Scripts

Scripts to simplify [operational task](Docs/operational-scripts.md) are provided. Examples are:

* `Build-PolicyDocumentation` generates [documentation in markdown and csv formats for Policy Sets and Assignments.](Docs/documenting-assignments-and-policy-sets.md)
* `Create-AzRemediationTasks` to bulk remediate non-compliant resources for Policies with `DeployIfNotExists` or `Modify` effects.

### Microsoft's Security & Compliance for Cloud Infrastructure

This `enterprise-policy-as-code` **(EPAC)** repo has been developed in partnership with the Security & Compliance for Cloud Infrastructure (S&C4CI) offering available from Microsoft's Industry Solutions (Consulting Services). Microsoft Industry Solutions can assist you with securing your cloud. S&C4CI improves your new or existing security posture in Azure by securing platforms, services, and workloads at scale.

## Understanding EPAC Environments and the pacSelector

> ---
> ---
>> **IMPORTANT**
>
> ---
> ---
>
> EPAC has a concept of an environment identified by a string (unique per repository) called `pacSelector`. An environment associates the following with the `pacSelector`:
>
> * `cloud` - to select sovereign cloud environments.
> * `tenantId` - enables multi-tenant scenarios.
> * `rootDefinitionScope` - scope for the Policy and Policy Set definitions.
>
>> Note: Policy Assignments can only defined at this root scope and child scopes (recursive).
>
> * Optional: define `desiredState`
>
> These associations are stored in `global-settings.jsonc` in an element called `pacEnvironments`.
>
> Like any other software or IaC solution, EPAC needs areas for developing and testing new Policies, Initiatives and Assignments before any deployment to EPAC prod environments. In most cases you will need one management group hierarchy to simulate EPAC production management groups for development and testing of Policies. EPAC's prod environment will govern all other IaC environments (e.g., sandbox, development, integration, test/qa, pre-prod, prod, ...) and tenants. This can be confusing. We will use EPAC environment(s) and IaC environments to disambiguate the environments.
>
> In a centralized single tenant scenario, you will define two EPAC environments: epac-dev and tenant. In a multi-tenant scenario, you will add an additional EPAC environment per additional tenant.
>
> The `pacSelector` is just a name. We highly recommend to call the Policy development environment `epac-dev`, you can name the EPAC prod environments in a way which makes sense to you in your environment. We use `tenant`, `tenant1`, etc in our samples and documentation.
>
> These names are used and therefore must match:
>
> * Defining the association (`pacEnvironments`) of an EPAC environment, `managedIdentityLocation` and `globalNotScopes` in `global-settings.jsonc`
> * Script parameter when executing different deployment stages in a CI/CD pipeline or semi-automated deployment targeting a specific EPAC environments.
> * `scopes` and `notScopes` definitions in Policy Assignment JSON files.
>
> ---
> ---

 <br/>

## Approach Flexibility

### CI/CD Scenarios

The solution supports any DevOps CI/CD approach you desire. The starter kits assume a GitHub flow approach to branching and CI/CD integration with a standard model below.

* **Simple**
  * Create a feature branch
  * Commits to the feature branch trigger:
    * Plan and deploy changes to a Policy development Management Group or subscription.
    * Create a plan (based on feature branch) for te EPAC production environment(s)/tenant(s).
  * Pull request (PR) merges trigger:
    * Plan and deploy from the merged main branch to your EPAC production environment(s) without additional approvals.
* **Standard** - starter kits implement this approach
  * Create a feature branch
  * Commits to the feature branch trigger:
    * Plan and deploy changes to a Policy development Management Group or subscription
    * Create a plan (based on feature branch) for te EPAC production environment(s)/tenant(s).
  * Pull request (PR) merges trigger:
    * Plan from the merged main branch to your EPAC production environment(s).
  * Approval gate for plan deployment is inserted.
  * Deploy the planned changes to environment(s)/tenant(s)
    * Deploy Policy, Policy Set (Initiative) definitions, Policy Assignments and Policy Exemptions
    * [Recommended] Approval gate for Role assignment is inserted.
    * Deploy Role assignment for Policy required Managed Identities.

### Coexistence and Desired State Strategy

EPAC is a desired state system. It will remove Policy resources in an environment which are not defined in the definition files. To facilitate transition from previous Policy implementations and coexistence of multiple EPAC and third party Policy as Code systems, a granular way to control such coexistence is implemented. Specifically, EPAC supports:

* **Centralized**: One centralized team manages all Policy and Initiative assignments in the Azure organization, at all levels (Management Group, Subscription, Resource Group). This is the default setup.
* **Distributed**: Multiple teams manage Policy and Initiative assignments in a distributed manner. Distributed is also useful during a brownfield deployment scenario to allow for an orderly transition from pre-EPAC to EPAC.

Desired state strategy documentation can be found [here.](Docs/desired-state-strategy.md)

> ---
>
> **Desired State Warning**
>
> If you have a existing Policy definitions, Policy Set (Initiative) definitions, Policy assignments, and Policy exemptions in your environment, you have not transferred to EPAC, do not forget to *include* the new `desiredState` element with a `strategy` of `ownedOnly`. This is the equivalent of the deprecated "brownfield" variable in the pipeline. The default `strategy` is `full`.
>
> * *`full` deletes any Policy definitions, Policy Set (Initiative) definitions, Policy assignments, and Policy exemptions not deployed by this EPAC solution or another EPAC solution.*
> * *`ownedOnly` deletes only Policies with this repos’s pacOwnerId. This allows for a gradual transition from your existing Policy management to Enterprise Policy as Code.*
>
> Policy resources with another pacOwnerId metadata field are never deleted.
>
> ---

<br/>

## Quick Start

### Create your environment

* [Setup DevOps Environment](Docs/operating-environment.md) for your developers (on their workstations) and your CI/CD pipeline runners/agents (on a VM or set of VMs) to facilitate correct implementations. Operating Environment Prerequisites:** The EPAC Deployment process is designed for DevOps CI/CD. It requires the [installation of several tools] to facilitate effective development, testing, and deployment during the course of a successful implementation.
* [Create a source repository and import the source code](Docs/clone-github.md) from this repository.

### Define your deployment scenarios

* [Select the desired state strategy](Docs/desired-state-strategy.md).
* Copy starter kit pipeline definition and definition folder to your folders.
* [Define your deployment environment](Docs/definitions-and-global-settings.md) in `global-settings.jsonc`.

### Create the CI/CD (skip if using the semi-automated approach)

* [Build your CI/CD pipeline](Docs/ci-cd-pipeline.md) using a starter kit.

### Build your definitions and assignments

* [Add custom Policy definitions](Docs/policy-definitions.md).
* [Add custom Policy Set definitions](Docs/policy-set-definitions.md).
* [Create Policy Assignments](Docs/policy-assignments.md).
* Or import Policies from the [Cloud Adoption Framework](Docs/cloud-adoption-framework.md).

### Manage your Policy environment

* [Manage Policy Exemptions](Docs/policy-exemptions.md).
* [Document your deployments](Docs/documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](Docs/operational-scripts.md).

### Debug EPAC issues

Should you encounter issues with the expected behavior of EPAC, try the following:

* Run the scripts interactively.
* [Debug the scripts in VS Code](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/using-vscode?view=powershell-7.3).
* Ask for help by raising a [GitHub Issue](https://github.com/Azure/enterprise-azure-policy-as-code/issues/new)

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
