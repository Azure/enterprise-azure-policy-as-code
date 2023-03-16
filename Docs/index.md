## Overview

Enterprise Policy as Code or EPAC for short comprises a number of scripts which can be used in CI/CD based system or a semi-automated use to deploy Policies, Policy Sets, Assignments, Policy Exemptions and Role Assignments.

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

## Deployment Scripts

Three deployment scripts plan a deployment, deploy Policy resources, and Role Assignments respectively as shown in the following diagram. The solution consumes definition files (JSON and/or CSV files). The planning script (`Build-DeploymentPlan`) creates plan files (`policy-plan.json` and `roles-plan.json`) to be consumed by the two deployment steps (`Deploy-PolicyPlan` and `Deploy-RolesPlan`). The scripts require `Reader`, `Contributor` and `User Access Administrator` privileges respectively as indicated in blue text in the diagram. The diagram also shows the usual approval gates after each step/script for prod deployments.

![image.png](Images/epac-deployment-scripts.png)

<br/>

## CI/CD Tool Compatibility

Since EPAC is based on PowerShell scripts, any CI/CD tool with the ability to execute scripts can be used. The starter kits currently include pipeline definitions for Azure DevOps. Additional starter kits are being implemented and will be added in future releases.

## Multi-Tenant Support

EPAC supports single and multi-tenant deployments from a single source. In most cases you should have a fully or partially isolated area for Policy development and testing, such as a Management Group. An entire tenant can be used; however, it is not necessary since EPAC has sophisticated partitioning capabilities.

## Operational Scripts

Scripts to simplify [operational task](operational-scripts.md) are provided. Examples are:

* `Build-PolicyDocumentation` generates [documentation in markdown and csv formats for Policy Sets and Assignments.](documenting-assignments-and-policy-sets.md)
* `Create-AzRemediationTasks` to bulk remediate non-compliant resources for Policies with `DeployIfNotExists` or `Modify` effects.

## Microsoft's Security & Compliance for Cloud Infrastructure

This `enterprise-policy-as-code` **(EPAC)** repo has been developed in partnership with the Security & Compliance for Cloud Infrastructure (S&C4CI) offering available from Microsoft's Industry Solutions (Consulting Services). Microsoft Industry Solutions can assist you with securing your cloud. S&C4CI improves your new or existing security posture in Azure by securing platforms, services, and workloads at scale.

## Understanding EPAC Environments and the pacSelector

!!! warning
> EPAC has a concept of an environment identified by a string (unique per repository) called `pacSelector`. An environment associates the following with the `pacSelector`:
>
> * `cloud` - to select commercial or sovereign cloud environments.
> * `tenantId` - enables multi-tenant scenarios.
> * `rootDefinitionScope` - scope for Policy and Policy Set definitions.
>
>> Note: Policy Assignments can only defined at this root scope and child scopes (recursive).
>
> * Optional: define `desiredState`
>
> These associations are stored in `global-settings.jsonc` in an element called `pacEnvironments`.
>
> Like any other software or IaC solution, EPAC needs areas for developing and testing new Policies, Policy Sets and Assignments before any deployment to EPAC prod environments. In most cases you will need one management group hierarchy to simulate EPAC production management groups for development and testing of Policies. EPAC's prod environment will govern all other IaC environments (e.g., sandbox, development, integration, test/qa, pre-prod, prod, ...) and tenants. This can be confusing. We will use EPAC environment(s) and IaC environment(s) to disambiguate the environments.
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

## Approach Flexibility

## CI/CD Scenarios

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

## Coexistence and Desired State Strategy

EPAC is a desired state system. It will remove Policy resources in an environment which are not defined in the definition files. To facilitate transition from previous Policy implementations and coexistence of multiple EPAC and third party Policy as Code systems, a granular way to control such coexistence is implemented. Specifically, EPAC supports:

* **Centralized**: One centralized team manages all Policy resources in the Azure organization, at all levels (Management Group, Subscription, Resource Group). This is the default setup.
* **Distributed**: Multiple teams manage Policy resources in a distributed manner. Distributed is also useful during a brownfield deployment scenario to allow for an orderly transition from pre-EPAC to EPAC.

Desired state strategy documentation can be found [here.](desired-state-strategy.md)


!!! warning
    If you have a existing Policies, Policy Sets, Assignments, and Exemptions in your environment, you have not transferred to EPAC, do not forget to *include* the new `desiredState` element with a `strategy` of `ownedOnly`. This is the equivalent of the deprecated "brownfield" variable in the pipeline. The default `strategy` is `full`.

    * *`full` deletes any Policies, Policy Sets, Assignments, and Exemptions not deployed by this EPAC solution or another EPAC solution.*
    * *`ownedOnly` deletes only Policies with this repos’s pacOwnerId. This allows for a gradual transition from your existing Policy management to Enterprise Policy as Code.*

    Policy resources with another pacOwnerId metadata field are never deleted.

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
