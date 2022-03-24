# Policy as Code

This repository contains a mature solution to manage and deploy Azure Policy at enterprise scale.

**Note:** Don Koning has published great guidance on naming conventions and other recommendations [here](https://github.com/DonKoning/DonKoning/blob/main/AzurePolicy/Governance/Azure%20Policy%20Governance.docx)

## Azure Security Modernization

This repo has been developed in partnership with the Azure Security Modernization (ASM) offering within Microsoft's Industry Solutions (Consulting Services)

ASM improves your new or existing security posture in Azure by securing platforms, services, and workloads at any scale. ASM revolves around a continuous security improvement model (Measure, Plan, Develop & Deliver) giving visibility into security vulnerabilities.

## Warning

This solution uses the desired state strategy. It will remove any custom Policies, Initiatives or Policy Assignments not duplicated in the definition files. The `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` script's switch parameter `SuppressDeletes` changes this behavior. Use a "brownfield" pipeline to pass this parameter preventing deletions of existing Policies, Initiatives and Policy Assignments while transitioning to Enterprise Policy as Code.

## Starter Kit

Folder `StarterKit` contains pipelines and definitions. Copy them as starters to your `Pipelines` and `Definitions` folders. This separation will facilitate updates from the GitHub repo to your fork or local clone. Your modified files should be in `Definitions` or `Pipeline` folder. These folders in the original repo contain only a README.md file; therefore your pipeline and definition files are never overwritten when copying the latest updates.

### Azure DevOps Starter Pipelines

- Single tenant pipelines
  - Without Role Assignments separated into an additional stage
    - Regular: `pipeline-simple.yml`
    - Brownfield (SuppressDeletes): `brownfield-pipeline-simple.yml`
  - With Role Assignments separated to facilitate a second approval gate
    - Regular `pipeline-separate-roles.yml`
    - Brownfield (SuppressDeletes): `brownfield-pipeline-simple.yml`
- Multi tenant pipelines
  - Not yet implemented.

### GitHub Starter Pipelnes

Not yet implemented.

### Customizing your Pipeline

Pipelines can customized to fit your needs:

- Multiple tenants.
- Pull Request triggers (omitted due to the excessive time consumption).
- Simplified flows, such as now approvals needed (not a recommended practice).
- More sophisticated flows.
- Different development approach instead of GitHub flow.
- ...

## Components

| Component | What is it used for? | Where can it be found? |
|--|--|--|
| **Pipeline File** | Configure the deployment pipeline for Azure DevOps. **Copy a suitable sample pipeline from the samples provided to the working folder.** | Working folder: `Pipeline` <br/> Starter pipelines: <br/> `StarterKit/Pipelines` |
| **Definition Files** | Define custom policies, initiatives and assignments. This repo contains a sample for each. **Copy suitable samples as starters from the samples provided to the working folder.** | Working folder: <br/> `Definitions` <br/> Starter definitions: <br/>  `StarterKit/Definitions` |
| **Service Connections** | Service connections give the pipeline the proper permissions to deploy at desired Azure scopes. [Documentation for Service Connections](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints) | Azure DevOps <br/> project settings  |
| **Deployment Scripts** | Scripts are used to deploy your Policies, Initiatives, and Assignments to Azure. They do not need to be modified. If you have improvements, please offer to contribute them. | Folder `Scripts/Deploy` |
| **Operational Scripts** | Scripts used to during operations (e.g., creating remediation tasks). | Folder `Scripts/Operations` |
| **Helper and Utility Scripts** | These Scripts are used by other scripts. | Folders `Scripts/Helpers` and <br/>`Scripts/Utils` |
| **Test Scripts** | Scripts used by this solution's developers to execute other scripts without needing to type all the parameters each time. | Folder <br/> `Scripts/Test` |

<br/>[Back to top](#policy-as-code)<br/>

## Scenarios

The Policy as Code framework supports the following Policy and Initiative assignment scenarios:

- **Centralized approach**: One centralized team manages all policy and initiative assignments in the Azure organization, at all levels (Management Group, Subscription, Resource Group).
- **Distributed approach**: Multiple teams can also manage policy and initiative assignments in a distributed manner if there's a parallel set Management Group hierarchies defined. In this case individual teams can have their own top level Management group (and corresponding Management Groups hierarchy with Subscriptions and Resource Groups below), but assignments must not be made on the Tenant Root Group level.
  > **NOTE**: Distributed teams must only include those scopes in their version of the assignments.json that is not covered by another team.
- **Mixed approach**: A centralized team manages policy and initiative assignments to a certain level (top-down approach), e.g. on the Tenant Root Group level, and top level Management group, and all assignments on lower levels (i.e. lower level Management Groups, Subscriptions and Resource Groups) are managed by multiple teams, in a distributed manner.

 **NOTE**: This solution enforces a centralized approach. It is recommended that you follow a centralized approach however, when using the mixed approach, scopes that will not be managed by the central team should be excluded from the assignments JSON file - therefore the assignment configuration script will ignore these scopes (it won't add/remove/update anything in there). Conversly, the distributed teams must only include those scopes in their version of the assignments.json that is not covered by the central team.

 <br/>[Back to top](#policy-assignments)<br/>

## Policy as Code Environments

This solution requires environments for DEV, optional DEVINT, TEST and one PROD per tenant. These environments are not the same as the standard Azure environments for solutions - do not confuse them. The regular Sandbox, DEV, DEVINT, TEST/QA and PROD environment are managed with the PaC PROD environment(s).

The scripts have a parameter `PacEnvironmentSelector` to select the PaC environment. This string must match the selectors in `global-settings.jsonc` and the Policy Assignment files to select the scopes and notScopes. The scripts accept the parameter directly. If the parameter is missing, the scripts prompt for it interactively.

 <br/>[Back to top](#policy-assignments)<br/>

## Prerequisites

- Build a management group dedicated to Policy as Code (PaC) -- `mg-pac-dev` <br/> <https://docs.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal>
- Create two subscriptions under the PaC management group mg-pac-dev. Recommended naming:
  - PAC-DEV-001
  - PAC-TEST-001
  - <https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription>
- Note on Multi-Tenant:
  - Azure DevOps Server (if not using Azure DevOps service) and Azure Self-Hosted Agents must be in PROD tenant.
  - Management Group `mg-pac-dev` should be creted in a dev tenant

<br/>[Back to top](#policy-as-code)<br/>

## Quick Start

1. Create an Azure DevOps project dedicated to Policy as Code (PaC). You may also create a dedicated PaC repo within an existing Azure DevOps project.
1. Import this repository into the newly created PaC repository: <br/> <https://docs.microsoft.com/en-us/azure/devops/repos/git/import-git-repository?view=azure-devops>
    - We recommend that you only modify the folders `Pipeline` and `Definitions` to facilitate merging updates from this repo.
    - However, do not modify the README.md files in folders `Pipeline` and `Definitions`
1. Define the environment specific settings in **[global-settings.jsonc](Definitions/README.md)**
    - For Policy Assignments only:
        - managedIdentityLocation for remediation tasks
        - notScope to globally exclude Management Groups and Resource Groups
    - Scope definition
        - tenant
        - defaultSubscription
        - rootScope
        - plan file names
    - Representative assignments to calculate effective effects spreadsheet
    - Initiatives to compare
1. Create a custom role to be used by the planing stages' service connections **Policy Reader role**. Script `./Scripts/Operations/New-AzPolicyReaderRole.ps1` will create the role at the scope defined in `global-settings.json`. It will contain:
   - `Microsoft.Authorization/policyAssignments/read`
   - `Microsoft.Authorization/policyDefinitions/read`
   - `Microsoft.Authorization/policySetDefinitions/read`
1. Create the Service Connections in Azure DevOps with the required permissions as documented in the **[Pipeline documentation](Pipeline/README.md)**.

1. Configure the deployment pipeline
   - Register the pipeline.
   - Modify the pipeline to include the service connections, environments and triggers as needed: **[pipeline documentation](Pipeline/README.md)**.

1. Create environments in Azure DevOps. Environments must be created to isolate deployment controls and set approval gates.

    - Single tenant
      - PAC-ROLES
      - PAC-PROD
      - PAC-TEST
      - PAC-DEV
    - Multi tenant
      - PAC-ROLES-t1
      - PAC-PROD-t1
      - PAC-ROLES-t2
      - PAC-PROD-t2
      - PAC-TEST
      - PAC-DEV
    - If you would like to modify the names of these environments, you must also modify the pipeline environments for each stage in the pipeline file.

1. Create policies, initiatives, and assignments as needed
   - Follow the included file structures
   - **NOTE:** if you are NOT creating a greenfield environment, you may add the suppress delete operator to the pipeline file to keep previous policies, initiatives, and assignments. Add the `-suppressDeletes` switch parameter to every instance of script `Build-AzPoliciesInitiativesAssignmentsPlan.ps1`.

     ```yaml
     scriptPath: "Scripts/Deploy/Build-AzPoliciesInitiativesAssignmentsPlan.ps1"
     arguments: -TenantId $(tenantId) `
       -PacEnvironmentSelector $(devPacEnvironmentSelector) `
       -PlanFile $(devPlanFile) `
       -InformationAction Continue `
       -suppressDeletes
     ```

1. Trigger the pipeline to deploy to each envrionment with these actions. The example pipelines have two sections triggered differently:
    - Triggered by a commit to a feature branch: stages devAllStage and prodPlanFeatureStage
    - Triggered by a commit to a feature branch: stages prodPlanMainStage, prodDeployStage, (optional) prodRolesStage, prodNoPolicyChangesStage, and prodNoRoleChangesStage (optional).
    - You may add additional sections for other triggers, such as pre-PR test build and deploy stages.

<br/>[Back to top](#policy-as-code)<br/>

## Reading List

1. **[Pipeline](Pipeline/README.md)**

1. **[Update Global Settings](Definitions/README.md)**

1. **[Create Policy Definitions](Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](Definitions/Assignments/README.md)**

1. **[Scripts](Scripts/README.md)**

[Back to top](#policy-as-code) <br/>

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

<br/>[Back to top](#policy-as-code)<br/>

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.

<br/>[Back to top](#policy-as-code)<br/>
