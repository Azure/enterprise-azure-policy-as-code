# Enterprise Azure Policy as Code V6.0

!!! warning
 **Breaking changes in V6.0 and v7.0**
 Substantial feature enhancements required breaking changes in v6.0 and to a lesser extend v7.0.

 [Breaking change details and instructions on upgrading from a previous version](Docs/breaking-changes.md).

!!! warning
 **Az PowerShell Module 9.2.x has a known issue (bug).** This bug causes multiple failures of EPAC and any other Policy as Code solution depending on Az Module. **Az PowerShell Module 9.3.0 fixed this issue.**

## Terminology

| Full name | Simplified use in this documentation |
| :-------- | :----------------------------------- |
| Policy definition(s) | Policy, Policies |
| Initiative definition(s) or Policy Set definition(s) | Policy Set(s) |
| Policy Assignment(s) of a Policy or Policy Set | Assignment(s) |
| Policy Assignment(s) of a Policy Set | Policy Set Assignment |
| Policy Exemption(s) | Exemption(s) |
| Role Assignment(s)s for Managed Identities required by Policy Assignments | Role Assignment(s) |
| Policies, Policy Sets, Assignments **and** Exemptions | Policy resources |

## Overview

Enterprise Policy as Code or EPAC for short comprises a number of scripts which can be used in CI/CD based system or a semi-automated use to deploy Policies, Policy Sets, Assignments, Policy Exemptions and Role Assignments.

### Deployment Scripts

**Three deployment scripts plan a deployment, deploy Policy resources, and Role Assignments** respectively as shown in the following diagram. The solution consumes definition files (JSON and/or CSV files). The planning script (`Build-DeploymentPlan`) creates plan files (`policy-plan.json` and `roles-plan.json`) to be consumed by the two deployment steps (`Deploy-PolicyPlan` and `Deploy-RolesPlan`). The scripts require `Reader`, `Contributor` and `User Access Administrator` privileges respectively as indicated in blue text in the diagram. The diagram also shows the usual approval gates after each step/script for prod deployments.

![image.png](Docs/Images/epac-deployment-scripts.png)

### CI/CD Tool Compatibility

Since EPAC is based on PowerShell scripts, any CI/CD tool with the ability to execute scripts can be used. The starter kits currently include pipeline definitions for Azure DevOps and Github Actions. Additional starter kits are being implemented and will be added in future releases.

### Multi-Tenant Support

EPAC supports single and multi-tenant deployments from a single source. In most cases you should have a fully or partially isolated area for Policy development and testing, such as a Management Group. An entire tenant can be used; however, it is not necessary since EPAC has sophisticated partitioning capabilities.

### Operational Scripts

Scripts to simplify [operational task](Docs/operational-scripts.md) are provided. Examples are:

* `Build-PolicyDocumentation` generates [documentation in markdown and csv formats for Policy Sets and Assignments.](Docs/documenting-assignments-and-policy-sets.md)
* `Create-AzRemediationTasks` to bulk remediate non-compliant resources for Policies with `DeployIfNotExists` or `Modify` effects.

### Microsoft's Security & Compliance for Cloud Infrastructure

This `enterprise-policy-as-code` **(EPAC)** repo has been developed in partnership with the Security & Compliance for Cloud Infrastructure (S&C4CI) offering available from Microsoft's Industry Solutions (Consulting Services). Microsoft Industry Solutions can assist you with securing your cloud. S&C4CI improves your new or existing security posture in Azure by securing platforms, services, and workloads at scale.

## Understanding EPAC Environments and the pacSelector

!!! note
 Understanding of this concept is crucial. Do **not** proceed until you completely understand the implication.

EPAC has a concept of an environment identified by a string (unique per repository) called `pacSelector`. An environment associates the following with the `pacSelector`:

* `cloud` - to select commercial or sovereign cloud environments.
* `tenantId` - enables multi-tenant scenarios.
* `rootDefinitionScope` - scope for Policy and Policy Set definitions.
* Optional: define `desiredState`

!!! note
 Policy Assignments can only defined at `rootDefinitionScope` and child scopes (recursive).

These associations are stored in `global-settings.jsonc` in an element called `pacEnvironments`.

Like any other software or IaC solution, EPAC needs areas for developing and testing new Policies, Policy Sets and Assignments before any deployment to EPAC prod environments. In most cases you will need one management group hierarchy to simulate EPAC production management groups for development and testing of Policies. EPAC's prod environment will govern all other IaC environments (e.g., sandbox, development, integration, test/qa, pre-prod, prod, ...) and tenants. This can be confusing. We will use EPAC environment(s) and IaC environment(s) to disambiguate the environments.

In a centralized single tenant scenario, you will define two EPAC environments: epac-dev and tenant. In a multi-tenant scenario, you will add an additional EPAC environment per additional tenant.

The `pacSelector` is just a name. We highly recommend to call the Policy development environment `epac-dev`, you can name the EPAC prod environments in a way which makes sense to you in your environment. We use `tenant`, `tenant1`, etc in our samples and documentation. These names are used and therefore must match:

* Defining the association (`pacEnvironments`) of an EPAC environment, `managedIdentityLocation` and `globalNotScopes` in `global-settings.jsonc`
* Script parameter when executing different deployment stages in a CI/CD pipeline or semi-automated deployment targeting a specific EPAC environments.
* `scopes`, `notScopes`, `additionalRoleAssignments`, `managedIdentityLocations`, and `userAssignedIdentity` definitions in Policy Assignment JSON files.

## Approach Flexibility

### CI/CD Scenarios

The solution supports any DevOps CI/CD approach you desire. The starter kits assume a GitHub flow approach to branching and CI/CD integration with a standard model below.

* **Simple**
  * Create a feature branch
  * Commits to the feature branch trigger:
    * Plan and deploy changes to a Policy resources development Management Group or subscription.
    * Create a plan (based on feature branch) for te EPAC production environment(s)/tenant(s).
  * Pull request (PR) merges trigger:
    * Plan and deploy from the merged main branch to your EPAC production environment(s) without additional approvals.
* **Standard** - starter kits implement this approach
  * Create a feature branch
  * Commits to the feature branch trigger:
    * Plan and deploy changes to a Policy resources development Management Group or subscription
    * Create a plan (based on feature branch) for te EPAC production environment(s)/tenant(s).
  * Pull request (PR) merges trigger:
    * Plan from the merged main branch to your EPAC production environment(s).
  * Approval gate for plan deployment is inserted.
  * Deploy the planned changes to environment(s)/tenant(s)
    * Deploy Policy resources.
    * [Recommended] Approval gate for Role Assignment is inserted.
    * Deploy Role Assignment.

### Coexistence and Desired State Strategy

EPAC is a desired state system. It will remove Policy resources in an environment which are not defined in the definition files. To facilitate transition from previous Policy implementations and coexistence of multiple EPAC and third party Policy as Code systems, a granular way to control such coexistence is implemented. Specifically, EPAC supports:

* **Centralized**: One centralized team manages all Policy resources in the Azure organization, at all levels (Management Group, Subscription, Resource Group). This is the default setup.
* **Distributed**: Multiple teams manage Policy resources in a distributed manner. Distributed is also useful during a brownfield deployment scenario to allow for an orderly transition from pre-EPAC to EPAC.

Desired state strategy documentation can be found [here.](Docs/desired-state-strategy.md)

### Desired State Warning

If you have a existing Policies, Policy Sets, Assignments, and Exemptions in your environment, you have not transferred to EPAC, do not forget to *include* the new `desiredState` element with a `strategy` of `ownedOnly`. This is the equivalent of the deprecated "brownfield" variable in the pipeline. The default `strategy` is `full`.

* `full` deletes any Policies, Policy Sets, Assignments, and Exemptions not deployed by this EPAC solution or another EPAC solution.
* `ownedOnly` deletes only Policies with this repos’s pacOwnerId. This allows for a gradual transition from your existing Policy management to Enterprise Policy as Code.

Policy resources with another pacOwnerId metadata field are never deleted.

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

* Optional: generate a starting point for the `Definitions` subfolders:
  * [Extract existing Policy resources from an environment](Docs/extract-existing-policy-resources.md).
  * [Import Policies from the Cloud Adoption Framework](Docs/cloud-adoption-framework.md).
  * Use the sample Policy resource definitions in the starter kit.
* [Add custom Policies](Docs/policy-definitions.md).
* [Add custom Policy Sets](Docs/policy-set-definitions.md).
* [Create Policy Assignments](Docs/policy-assignments.md).

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
