# Enterprise Azure Policy as Code (EPAC)

!!! warning
**Az PowerShell Module 9.2.x has a known issue (bug).** This bug causes multiple failures of EPAC and any other Policy as Code solution depending on Az Module. **Az PowerShell Module 9.3.0 fixed this issue.**

## Overview

Enterprise Azure Policy as Code or EPAC for short comprises a number of scripts which can be used in CI/CD based system or a semi-automated use to deploy Policies, Policy Sets, Assignments, Policy Exemptions and Role Assignments.

!!! warning
Substantial feature enhancements required [breaking changes in v6.0 and to a lesser extend in v7.0](Docs/breaking-changes.md).

## Project Links

- [GitHub Repo](https://github.com/Azure/enterprise-azure-policy-as-code)
- [GitHub Issues](https://github.com/Azure/enterprise-azure-policy-as-code/issues)
- [Starter Kit](https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit)
- [Enterprise Policy as Code PowerShell Module](https://www.powershellgallery.com/packages/EnterprisePolicyAsCode)
- [Azure Enterprise Policy as Code – A New Approach](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/azure-enterprise-policy-as-code-a-new-approach/ba-p/3607843)
- [Azure Enterprise Policy as Code – Azure Landing Zones Integration](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/azure-enterprise-policy-as-code-azure-landing-zones-integration/ba-p/3607844)

## Microsoft's Security & Compliance for Cloud Infrastructure

This `enterprise-policy-as-code` **(EPAC)** repo has been developed in partnership with the Security & Compliance for Cloud Infrastructure (S&C4CI) offering available from Microsoft's Industry Solutions (Consulting Services). Microsoft Industry Solutions can assist you with securing your cloud. S&C4CI improves your new or existing security posture in Azure by securing platforms, services, and workloads at scale.

## Terminology

| Full name                                                                 | Simplified use in this documentation |
| :------------------------------------------------------------------------ | :----------------------------------- |
| Policy definition(s)                                                      | Policy, Policies                     |
| Initiative definition(s) or Policy Set definition(s)                      | Policy Set(s)                        |
| Policy Assignment(s) of a Policy or Policy Set                            | Assignment(s)                        |
| Policy Assignment(s) of a Policy Set                                      | Policy Set Assignment                |
| Policy Exemption(s)                                                       | Exemption(s)                         |
| Role Assignment(s)s for Managed Identities required by Policy Assignments | Role Assignment(s)                   |
| Policies, Policy Sets, Assignments **and** Exemptions                     | Policy resources                     |

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

- `Build-PolicyDocumentation` generates [documentation in markdown and csv formats for Policy Sets and Assignments.](documenting-assignments-and-policy-sets.md)
- `Create-AzRemediationTasks` to bulk remediate non-compliant resources for Policies with `DeployIfNotExists` or `Modify` effects.

## Understanding EPAC Environments and the pacSelector

!!! note
Understanding of this concept is crucial. Do **not** proceed until you completely understand the implications.

EPAC has a concept of an environment identified by a string (unique per repository) called `pacSelector`. An environment associates the following with the `pacSelector`:

- `cloud` - to select commercial or sovereign cloud environments.
- `tenantId` - enables multi-tenant scenarios.
- `rootDefinitionScope` - scope for Policy and Policy Set definitions.
- Optional: define `desiredState`

!!! note
Policy Assignments can only defined at `rootDefinitionScope` and child scopes (recursive).

These associations are stored in [global-settings.jsonc](definitions-and-global-settings.md) in an element called `pacEnvironments`.

Like any other software or IaC solution, EPAC needs areas for developing and testing new Policies, Policy Sets and Assignments before any deployment to EPAC prod environments. In most cases you will need one management group hierarchy to simulate EPAC production management groups for development and testing of Policies. EPAC's prod environment will govern all other IaC environments (e.g., sandbox, development, integration, test/qa, pre-prod, prod, ...) and tenants. This can be confusing. We will use EPAC environment(s) and IaC environment(s) to disambiguate the environments.

In a centralized single tenant scenario, you will define two EPAC environments: epac-dev and tenant. In a multi-tenant scenario, you will add an additional EPAC environment per additional tenant.

The `pacSelector` is just a name. We highly recommend to call the Policy development environment `epac-dev`, you can name the EPAC prod environments in a way which makes sense to you in your environment. We use `tenant`, `tenant1`, etc in our samples and documentation. These names are used and therefore must match:

- Defining the association (`pacEnvironments`) of an EPAC environment, `managedIdentityLocation` and `globalNotScopes` in `global-settings.jsonc`
- Script parameter when executing different deployment stages in a CI/CD pipeline or semi-automated deployment targeting a specific EPAC environments.
- `scopes`, `notScopes`, `additionalRoleAssignments`, `managedIdentityLocations`, and `userAssignedIdentity` definitions in Policy Assignment JSON files.

## CI/CD Scenarios Flexibility

The solution supports any DevOps CI/CD approach you desire. The starter kits assume a GitHub flow approach to branching and CI/CD integration with a standard model below.

- **Simple**
  - Create a feature branch
  - Commits to the feature branch trigger:
    - Plan and deploy changes to a Policy resources development Management Group or subscription.
    - Create a plan (based on feature branch) for te EPAC production environment(s)/tenant(s).
  - Pull request (PR) merges trigger:
    - Plan and deploy from the merged main branch to your EPAC production environment(s) without additional approvals.
- **Standard** - starter kits implement this approach
  - Create a feature branch
  - Commits to the feature branch trigger:
    - Plan and deploy changes to a Policy resources development Management Group or subscription
    - Create a plan (based on feature branch) for te EPAC production environment(s)/tenant(s).
  - Pull request (PR) merges trigger:
    - Plan from the merged main branch to your EPAC production environment(s).
  - Approval gate for plan deployment is inserted.
  - Deploy the planned changes to environment(s)/tenant(s)
    - Deploy Policy resources.
    - [Recommended] Approval gate for Role Assignment is inserted.
    - Deploy Role Assignment.

## Coexistence and Desired State Strategy

EPAC is a desired state system. It will remove Policy resources in an environment which are not defined in the definition files. To facilitate transition from previous Policy implementations and coexistence of multiple EPAC and third party Policy as Code systems, a granular way to control such coexistence is implemented. Specifically, EPAC supports:

- **Centralized**: One centralized team manages all Policy resources in the Azure organization, at all levels (Management Group, Subscription, Resource Group). This is the default setup.
- **Distributed**: Multiple teams manage Policy resources in a distributed manner. Distributed is also useful during a brownfield deployment scenario to allow for an orderly transition from pre-EPAC to EPAC.

Desired state strategy documentation can be found [here.](desired-state-strategy.md). The short version:

- `full` deletes any Policies, Policy Sets, Assignments, and Exemptions not deployed by this EPAC solution or another EPAC solution.\*
- `ownedOnly` deletes only Policies with this repos’s pacOwnerId. This allows for a gradual transition from your existing Policy management to Enterprise Policy as Code.\*
- Policy resources with another `pacOwnerId` `metadata` field are never deleted.

!!! warning
If you have a existing Policies, Policy Sets, Assignments, and Exemptions in your environment, you have not transferred to EPAC, do not forget to _include_ the new `desiredState` element with a `strategy` of `ownedOnly`. This is the equivalent of the deprecated "brownfield" variable in the pipeline. The default `strategy` is `full`.

## Understanding differences between usage of EPAC, AzAdvertizer and AzGovViz

Enterprise Policy-as-Code (EPAC), AzAdvertizer and Azure Governance Visualizer (AzGovViz) are three distinct open source projects or tools internally developed and maintained by Microsoft employees, each helping address different needs in enterprise scale management and governance of Azure environments.

- [AzAdvertizer](https://www.azadvertizer.net/) - AzAdvertizer is a publicly accessible web service that provides continually up-to-date insights on new releases and changes/updates for different Azure Governance capabilities such as Azure Policy's built-in policy and initiative (policy set) definitions, Azure aliases, Azure security & regulatory compliance controls, Azure RBAC built-in role definitions and Azure resource provider operations.

- [Azure Governance Visualizer (aka AzGovViz)](https://github.com/JulianHayward/Azure-MG-Sub-Governance-Reporting) - AzGovViz is an open source community project that provides visualization and reporting solution for any customer Azure environment or estate, delivering a rich set of detailed insights covering tenant management group hierarchies, RBAC assignments, Azure policy assignments, Blueprints, Azure network topology and much more. AzGovViz is listed as recommended tool in use for both Microsoft Cloud Adoption Framework (CAF) and Microsoft Well Architected Framework (WAF).

- [Enterprise Policy-as-Code (aka EPAC)](https://github.com/Azure/enterprise-azure-policy-as-code) - EPAC is an open source community project that provides a CI/CD automation solution for the development, deployment, management and reporting of Azure policy at scale. EPAC can maintain a policy "desired state" to provide a high level of assurance in highly controlled and sensitive environments, and a means of managing policy exemptions. While it uses standard JSON file structure for its repositories, operation and maintenance of policy and policy sets can actually be done via CSV files, reducing the skill expertise needed to operate the solution once implemented.

### Functional Comparison

The table below provides a summary functions/features comparison between the three solutions/tools.

| Function/Feature | AzAdvertizer | AzGovViz | EPAC |
| ---------------- | -------------|--------- | ---- |
| Purpose          | Detailed insight tool on released Azure public cloud governance features like current built-in polices and initiatives | Azure environment governance reporting and monitoring solution exposing tenant config/deployment detail of tenant hierarchies, RBAC assignments, policies, blueprints | Azure environment automated policy governance deployment, management and reporting solution |
| Implementation   | hosted web service | customer deployment, interactive Azure governance management and security reporting tool | customer deployment, deployment automation and reporting tool |
| Requirements     | browser | PowerShell 7.0.3 | PowerShell 7.3.1 |

## Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a
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
