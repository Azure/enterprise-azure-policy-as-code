# Enterprise Azure Policy as Code V6.0

> **Breaking changes in V6.0**
>
>> **Do to a reorganization of the source code and adding a substantial feature enhancement required breaking changes to the scripts, pipeline and global-settings.jsonc file.**
>
> **[Breaking change details and instructions on upgrading can be found here](Docs/breaking-chages-v6.0.md)**

## Table of Contents

In this file:

* [Table of Contents](#table-of-contents)
* [Security & Compliance for Cloud Infrastructure](#security--compliance-for-cloud-infrastructure)
* [Scenarios](#scenarios)
* [GitHub repository: How to clone or fork, update and contribute](#github-repository-how-to-clone-or-fork-update-and-contribute)
* [Quick start for advanced centralized approach](#quick-start-for-advanced-centralized-approach)
  * [Repo Updates With The Starter kit](#repo-updates-with-the-starter-kit)
  * [EPAC Resource Policy Reader role (custom)](#epac-resource-policy-reader-role-custom)
  * [Required Management Groups and subscriptions](#required-management-groups-and-subscriptions)
  * [Service connections for DevOps CI/CD](#service-connections-for-devops-cicd)
  * [EPAC environments setup](#epac-environments-setup)
  * [Azure DevOps CI/CD Pipeline](#azure-devops-cicd-pipeline)
  * [Edit and create Policies, Initiatives and Assignments](#edit-and-create-policies-initiatives-and-assignments)
  * [Document your Assignments](#document-your-assignments)
* [GitHub Folder Structure](#github-folder-structure)
* [Sync-Repo.ps1](#sync-repops1)
* [Components](#components)
* [Reading List](#reading-list)
* [Contributing](#contributing)
* [Trademarks](#trademarks)

> ---
>
> **Desired State Warning**
>
> **If you have a existing Policy definitions, Policy Set (Initiative) definitions, Policy assignments, and Policy exemptions in your environment, you have not transferred to EPAC, do not forget to *include* the new `desiredState` element with a `strategy` of `ownedOnly`. This is the equivalent of the deprecated "brownfield" variable in the pipeline.**
>
> **This solution uses the desired state strategy. The default `strategy` is `full`.**
>
> * *`full` deletes any Policy definitions, Policy Set (Initiative) definitions, Policy assignments, and Policy exemptions not deployed by the EPAC solution or another EPAC solution.*
> * *`ownedOnly` deletes only Policies with this repos’s pacOwnerId. This allows for a gradual transition from your existing Policy management to Enterprise Policy as Code.*
>
> **Policy resources with another pacOwnerId metadata field are never deleted.**
>
> [Desired state strategy documentaion can be found here.](Docs/desired-state-strategy.md)
>
> ---

## Security & Compliance for Cloud Infrastructure

This `enterprise-policy-as-code` **(EPAC)** repo has been developed in partnership with the Security & Compliance for Cloud Infrastructure (S&C4CI) offering available from Microsoft's Industry Solutions (Consulting Services). Microsoft Industry Solutions can assist you with securing your cloud. S&C4CI improves your new or existing security posture in Azure by securing platforms, services, and workloads at any scale.

### Operating Environment Requirements

The EPAC Deployment process is Compliance as Code, which requires that [several tools](Docs/operating-environment.md) be available for effective development, testing, and deployment during the course of a successful implementation.

## Scenarios

The Policy as Code framework supports the following Policy and Initiative assignment scenarios:

* **Centralized approach**: One centralized team manages all policy and initiative assignments in the Azure organization, at all levels (Management Group, Subscription, Resource Group).
* **Distributed approach**: Multiple teams can also manage policy and initiative assignments in a distributed manner if there's a parallel set Management Group hierarchies defined. In this case individual teams can have their own top level Management group (and corresponding Management Groups hierarchy with Subscriptions and Resource Groups below), but assignments must not be made on the Tenant Root Group level.
  > **NOTE**: Distributed teams must only include those scopes in their version of the assignments.json that is not covered by another team.
* **Mixed approach**: A centralized team manages policy and initiative assignments to a certain level (top-down approach), e.g. on the Tenant Root Group level, and top level Management group, and all assignments on lower levels (i.e. lower level Management Groups, Subscriptions and Resource Groups) are managed by multiple teams, in a distributed manner.

 > **NOTE**: This solution enforces a centralized approach. It is recommended that you follow a centralized approach; however, the aforementioned methods are also supported. When using the ***mixed approach***, **scopes that will not be managed by the central team should be excluded from the assignments JSON file** to ensure that the assignment configuration script will ignore these scopes (it won't add/remove/update anything in there). Conversely, the distributed teams must only include those scopes in their version of the assignments.json that is not covered by the central team.

## GitHub repository: How to clone or fork, update and contribute

### Repo Syncronization

Git lacks a capability to ignore files/directories during a PR only. This repo has been organized so that Definitions and Pipeline folders (except for README.md files) are not touched by syncing latest update from GitHub to your repo or reverse syncing to contribute to the project.

1. Initial setup
      1. Create `MyForkRepo` as a fork or clone of [GitHub repo](https://github.com/Azure/enterprise-azure-policy-as-code).
      1. Create `MyWorkingRepo`.
            1. **Clone** your forked repo.
            1. Create a new repo from the clone (**do not** fork `MyForkRepo`)
1. Work in `MyWorkingRepo`
      1. While the root folder is not modified as part of the Sync-Repo process, it is recommended that this part of the file structure not be used for storage of any custom material other than new folders.
          1. You may add additional folders, such as a folder for your own operational scripts.
      1. Use only folders `Definitions` and `Pipeline`, except when working on fixes to be contributed back to GitHub.
          1. Review the [`Sync-Repo.ps1`](#sync-repops1) documentation for additional information on the folders which are destroyed and recreated as part of the version upgrade process for additional insight on this topic.
1. Syncing from GitHub repo.
      1. Fetch changes from GitHub to `MyForkRepo`.
      1. Execute [`Sync-Repo.ps1`](#sync-repops1) to copy files from `MyForkRepo` to `MyWorkingRepo` feature branch.
      1. PR `MyWorkingRepo` feature branch.
1. Contribute to GitHub
      1. Execute [`Sync-Repo.ps1`](#sync-repops1) to copy files from `MyWorkingRepo` to `MyForkRepo` feature branch.
          1. **Be sure not to copy internal references within your files during your sync to MyForkRepo.**
      1. PR `MyForkRepo` feature branch.
      1. PR changes in your fork (`MyForkRepo`) to GitHub.
      1. GitHub maintainers will review the PR.

![image](./Docs/Images/Sync-Repo.png)

## Quick start for advanced centralized approach

This quick start is meant as an overview. **We highly recommend that you read the entire reading list before starting.**

### Repo updates with the starter kit

The solution includes a starter kit (folder `/StarterKit`) to create a baseline deployment.

1. Copy the contents of the `StarterKit/Definitions` folder to `Definitions` folder.
1. Copy the pipeline definition(s) for your DevOps deployment solution (for example: Azure DevOps, GitHub) to the `Pipeline` folder.

### EPAC Resource Policy Reader role (custom)

Create a custom role to be used by the planing stages' service connections **EPAC Policy Reader role**. Script `./Scripts/Operations/New-AzPolicyReaderRole.ps1` will create the role at the scope defined in `global-settings.json`. It will contain:

* `Microsoft.Management/register/action`
* `Microsoft.Authorization/policyassignments/read`
* `Microsoft.Authorization/policydefinitions/read`
* `Microsoft.Authorization/policyexemptions/read`
* `Microsoft.Authorization/policysetdefinitions/read`
* `Microsoft.PolicyInsights/*`
* `Microsoft.Support/*`

### Required Management Groups and subscriptions

This solution requires EPAC environments for development, (optional) integration, and production per Azure tenant. These EPAC environments are not the same as the standard Azure environments for applications or solutions - do not confuse them; EPAC non-prod environment are only for development and integration of Azure Policy.  The standard Azure Sandbox, DEV, DEVINT, TEST/QA and PROD app solution environments are managed with policy deployed from the EPAC PROD environment.

* Build a management group dedicated to Policy as Code (PaC) -- `mg-pac-dev` <br/> <https://docs.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal>
* Create two subscriptions under the PaC management group mg-pac-dev. Recommended naming:
  * PAC-DEV-001
  * PAC-TEST-001
  * <https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription>
* Note on Multi-Tenant:
  * Azure DevOps Server (if not using Azure DevOps service) and Azure Self-Hosted Agents must be in PROD tenant.
  * Management Group `mg-pac-dev` should be created in a development tenant

> **Note:** The purpose of the EPAC-DEV hierarchy is to simulate the deployment as each feature is integrated. The purpose of the EPAC-Test environment is to simulate the deployment as the collection of features are deployed at once to a new environment, as it will be in the Production Tenant that environment is reached in later deployment steps. **Only objects that are part of the assignment object hierarchy defined in exceptions and assignments should exist within these management groups defined in the [global-settings.jsonc file](./StarterKit/Definitions/global-settings.jsonc) as they are not intended to test anything but the deployment itself.**

### Service connections for DevOps CI/CD

Create Service Principals for the pipeline execution and setup your DevOps environment with the necessary service connections. You will need SPNs with specific roles:

* EPAC Development and Test subscriptions
  * Owner role at subscription for deploying to your EPAC development subscription
  * Owner role at subscription for deploying to your EPAC test subscription
* Per Azure tenant at your highest Management Group (called rootScope in EPAC vernacular)
  * Security Reader and EPAC Policy Reader (custom) or Policy Contributor roles for planning the EPAC prod deployment
  * Security Reader and Policy Contributor for deploying Policies, Initiatives and Assignments in the EPAC prod environment
  * User Access Administrator for assigning roles to the Assignments' Managed Identities (for remediation tasks) in the EPAC prod environment

> **Note:**
> When creating a Service Connection in Azure DevOps you can set up the service connections on a Subscription or a Management Group scope level, when configuring the service connection for the EPAC Developer and Test subscriptions the service connections scope level is **Subscription**, however when creating a Service Connections for EPAC Prod Plan, EPAC Prod Deployment and EPAC Role Assignment the service connection scope level is **Management Group**.

Subscription scope level | Management Group scope level
:-----------:|:----------------:
![image](./Docs/Images/azdoServiceConnectionSubConf.png) | ![image](./Docs/Images/azdoServiceConnectionMGConf.png)

### EPAC environments setup

Like any other software or X as Code solution, EPAC needs areas for developing and testing new Policies, Initiatives and Assignments before any deployment to EPAC prod environments. In most cases you will need one subscription each for EPAC development and EPAC testing. EPAC's prod environment will govern all other IaC app solution environments (e.g., sandbox, development, integration, test/qa, pre-prod, prod, ...). This can be slightly confusing.

**Note:** This solution will refer to EPAC environments which are selected with a PAC selector and the regular environments as simply environments.

The solution needs to know the Azure scopes for your EPAC environments. This is specified in the `global-settings.jsonc` file in the `Definitions` folder. `pacEnvironments` defines the EPAC environments:

```jsonc
    "pacEnvironments": [
        {
            "pacSelector": "epac-dev",
            "cloud": "AzureCloud",
            "tenantId": "77777777-8888-9999-1111-222222222222",
            "defaultSubscriptionId": "11111111-2222-3333-4444-555555555555",
            "rootScope": {
                "SubscriptionId": "11111111-2222-3333-4444-555555555555"
            }
        },
        {
            "pacSelector": "epac-test",
            "cloud": "AzureCloud",
            "tenantId": "77777777-8888-9999-1111-222222222222",
            "defaultSubscriptionId": "99999999-8888-7777-4444-333333333333",
            "rootScope": {
                "SubscriptionId": "99999999-8888-7777-4444-333333333333"
            }
        },
        {
            "pacSelector": "tenant",
            "cloud": "AzureCloud",
            "tenantId": "77777777-8888-9999-1111-222222222222",
            "defaultSubscriptionId": "99999999-8888-7777-4444-333333333333",
            "rootScope": {
                "ManagementGroupName": "Contoso-Root"
            }
        }
    ]
```

Explanations

* You will use the `pacSelector` values in your CI/CD pipeline and when executing operational scripts.
* `cloud` is used to select clouds (e.g., `AzureCloud`, `AzureUSGovernment`, `AzureGermanCloud`, ...).
* `tenantId` is the GUID of your Azure AD tenant
* `defaultSubscriptionId` is required to resolve Azure scopes correctly.
* `rootScope` defines the location of your custom Policy and Initiative definitions. It also denotes the highest scope for an assignment. The roles for the CI/CD SPNs must be assigned here.

We explain the `managedIdentityLocations` and `globalNotScopes` elements in `global-settings.jsonc` [here](Definitions/README.md).

### Azure DevOps CI/CD Pipeline

Setup your pipeline based on the provided starter kit pipeline. The yml file contains commented out sections to run in a IaaS Azure DevOps server (it requires a different approach to artifact storage) and for 2 additional tenants. Uncomment or delete the commented sections to fit your environment.

> **Desired State Warning**
>
> **If you have a existing Policies, Initiatives and Assignments in your environment, you have not transferred to EPAC, do not forget to change the "brownfield" variable in the pipeline to true.**

Pipelines can customized to fit your needs:

* Multiple tenants.
* Pull Request triggers (omitted due to the excessive time consumption).
* Simplified flows, such as now approvals needed (not a recommended practice).
* More sophisticated flows.
* Different development approach instead of GitHub flow.
* ...

### Edit and create Policies, Initiatives and Assignments

Using the starter kit edit the directories in the `Definitions` folder. To simplify entering parameters, you can use the [Initiative documenting feature](Definitions/Documentation/README.md#documenting-assignments-and-initiatives) which creates Markdown, CSV and a JSON parameter file. You need to specify your initiatives to be documented (folder [`Definitions\Documentation`](Definitions/Documentation/README.md#specifying-initiative-documentation)) and execute script [`./Scripts/Operations/Build-PolicyAssignmentDocumentation.ps1`](Scripts/Operations/README.md#build-policyassignmentdocumentationps1)

> **Note:** It is recommended that the csv parameter file be updated and used in the assignments folder to define the parameters used in the assignments that are being made.

### Document your Assignments

This solution can generate [documentation in markdown and csv formats](Definitions/Documentation/README.md).

## GitHub Folder Structure

![image](./Docs/Images/folder-structure.png)

## Sync-Repo.ps1

The repo contains a script to synchronize directories in both directions: `Sync-Repo.ps1`. It only works if you do not modify

* `Docs`, `Scripts` and `StarterKit` directories
* `README.md` files in Scripts and Pipeline folders
* `CODE_OF_CONDUCT.md`, `LICENSE`, `README.md` (this file), `SECURITY.md`, `SUPPORT.md` and `Sync-Repo.ps1` in root folder

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `sourceDirectory` | Required | Directory with the source (cloned or forked/cloned repo) |
| `destinationDirectory` | Required | Directory with the destination (cloned or forked/cloned repo) |
| `suppressDeleteFiles` | Optional | Switch parameter to suppress deleting files in `$destinationDirectory` tree |
| `omitDocFiles` | Optional | Switch parameter to exclude documentation files *.md, LICENSE, and this script from synchronization |

## Components

| Component | What is it used for? | Where can it be found? |
|--|--|--|
| **Pipeline File** | Configure the deployment pipeline for Azure DevOps. **Copy a suitable sample pipeline from the samples provided to the working folder.** | Working folder: `Pipeline` <br/> Starter pipelines: <br/> `StarterKit/Pipelines` |
| **Definition Files** | Define custom policies, initiatives and assignments. This repo contains a sample for each. **Copy suitable samples as starters from the samples provided to the working folder.** | Working folder: <br/> `Definitions` <br/> Starter definitions: <br/>  `StarterKit/Definitions` |
| **Service Connections** | Service connections give the pipeline the proper permissions to deploy at desired Azure scopes. [Documentation for Service Connections](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints) | Azure DevOps <br/> project settings  |
| **Deployment Scripts** | Scripts are used to deploy your Policies, Initiatives, and Assignments to Azure. They do not need to be modified. If you have improvements, please offer to contribute them. | Folder `Scripts/Deploy` |
| **Operational Scripts** | Scripts used to during operations (e.g., creating remediation tasks). | Folder `Scripts/Operations` |
| **Helper Scripts** | These Scripts are used by other scripts. | Folder `Scripts/Helpers` |
| **Cloud Adoption Framework Scripts** | The files in here are used to synchronize policies from the main ESLZ repository | Folder `Scripts\CloudAdoptionFramework` |

## Reading List

* [Pipeline - Azure DevOps](Docs/azure-devops-pipeline.md)
* [Update Global Settings](Docs/definitions-and-global-settings.md)
* [Create Policy Definitions](Docs/policy-definitions.md)
* [Create Policy Set (Initiative) Definitions](Docs/policy-set-definitions.md)
* [Define Policy Assignments](Docs/policy-assignments.md)
* [Define Policy Exemptions](Docs/policy-exemptions.md)
* [Documenting Assignments and Initiatives](Docs/documenting-assignments-and-policy-sets.md)
* [Operational Scripts](Docs/operational-scripts.md)
* **[Cloud Adoption Framework Policies](Docs/cloud-adoption-framework.md)**

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
