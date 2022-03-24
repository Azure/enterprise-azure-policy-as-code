# Pipeline

This article of the Policy as Code documentation contains all of the necessary information to configure, run and operate the deployment pipeline properly.

This repository contains starter pipeline definitions for Azure DevOps. **The authors are interested in supporting other deployment pipelines. If you have developed pipelines for other technologies, such as GitHub, Jenkins, ...**

## Starter Kit

Folder `StarterKit` contains pipelines and definitions. Copy them as starters to your `Pipelines` and `Definitions` folders. This separation will facilitate updates from the GitHub repo to your fork or local clone. Your modified file should be in `Definitions` or `Pipeline` folder. These folders contain only a README.md file; therefore your pipeline definition files are never overwritten.

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

## Customizing your Pipeline

Pipelines can customized to fit your needs:

- Multiple tenants.
- Pull Request triggers (omitted due to the excessive time consumption).
- Simplified flows, such as now approvals needed (not a recommended practice).
- More sophisticated flows.
- Different development approach instead of GitHub flow.
- ...

<br/>[Back to top](#pipeline)<br/>

## Components

The components required for **configuring the pipeline and deploying policies, initiatives, and assignments** are the following:

| Component | What is it used for? | Where can it be found? |
|--|--|--|
| **Pipeline File** | The 'pipeline.yml' file is used to configure the deployment pipeline in Azure DevOps. | In the `Pipeline` folder. |
| **Service Connections** | Service connections give the pipeline the proper permissions to deploy at desired Azure scopes | Refer to the following documentation:  <https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml>. |
| **Deployment Environments** | Creates distinct environment to configure approval gates. | Refer to the following documentation:  <https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments?view=azure-devops>
| **Deployment Scripts** | These scripts are used by the pipeline to deploy your policies, initiatives, and assignments to Azure | In the `Scripts` folder of this repository |

<br/>[Back to top](#pipeline)<br/>

## GitHub Flow for Policy as Code Flows

The diagram below shows the use of GitHub Flow in Policy as Code. Builds are triggered for Commits, optionally for Pull Requests and for successful main branch merges.

![image.png](../Docs/Images/PaC-GitHub-Flow.png)

<br/>[Back to top](#pipeline)<br/>

## Single Tenant Pipeline Stages with Role Separation

| Stage | Purpose | Trigger |
|-------|---------|---------|
| devAllStage | Feature branch DEV environment build, deploy and test | CI, Manual |
| prodPlanFeatureStage | Feature branch based plan for prod deployment | CI, Manual |
| testAllStage | Main branch TEST environment build, deploy and test | PR Merged, Manual |
| prodPlanMainStage | Main branch based plan for prod deployment | PR Merged, Manual |
| prodDeployStage | Deploy Policies defined by Main branch based plan | Prod stage approved |
| prodRolesStage | Assign roles defined by Main branch based plan | Role stage approved |
| prodNoPolicyStage | Empty stage to display that no Policy changes are needed | No Policy changes needed |
| prodNoRoleStage | Empty stage to display that no Role changes are needed | No Policy changes needed |

<br/>[Back to top](#pipeline)<br/>

## Service Connections and Roles

Create service connections for each of your environments and require minimum roles following the least privilege principle. If you have a single tenant, remove the last column and rows with connections ending in "-2".

| Connection | Stages  | PAC-DEV-001 | PAC-TEST-001 | Tenant 1 | Tenant 2 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| sc-pac-dev | devAllStage  | Owner ||||
| sc-pac-test    | testAllStage || Owner |||
| sc-pac-plan-1 | prodPlanFeatureStage <br/> prodPlanMainStage ||| Policy Reader ||
| sc-pac-plan-2 | prodPlanFeatureStage <br/> prodPlanMainStage |||| Policy Reader |
| sc-pac-prod-1 | prodDeployStage-1 ||| Policy Contributor ||
| sc-pac-prod-2 | prodDeployStage-2 |||| Policy Contributor |
| sc-pac-roles-1 | prodRolesStage-1 ||| User Administrator ||
| sc-pac-roles-2 | prodRolesStage-2 |||| User Administrator |
| none | prodNoPolicyStage-1 <br/> prodNoRoleStage-1 <br/> prodNoPolicyStage-2 </br> prodNoRoleStage-2 |||||

<br/>[Back to top](#pipeline)<br/>

## Deployment Scripts for Pipeline

### Scripts per Stage

| Stage | Scripts |
| :--- | :--- |
| devAllStage  | Build-AzPoliciesInitiativesAssignmentsPlan.ps1 <br> Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1 <br/> Set-AzPolicyRolesFromPlan.ps1
| prodPlanFeatureStage | Build-AzPoliciesInitiativesAssignmentsPlan.ps1
| testAllStage | Build-AzPoliciesInitiativesAssignmentsPlan.ps1 <br> Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1 <br/> Set-AzPolicyRolesFromPlan.ps1
| prodPlanMainStage | Build-AzPoliciesInitiativesAssignmentsPlan.ps1
| prodDeployStage | Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1
| prodRolesStage | Set-AzPolicyRolesFromPlan.ps1

<br/>[Back to top](#pipeline)<br/>

### Script Flow

<br/>

![image.png](../Docs/Images/PaC-Deploy-Scripts.png)

<br/>[Back to top](#pipeline)<br/>

### **Script:** Build-AzPoliciesInitiativesAssignmentsPlan.ps1

Analyzes changes in policy, initiative, and assignment files. It calculates a plan to apply deltas. The deployment scripts are **declarative** and **idempotent**: this means, that regardless how many times they are run, they always push all changes that were implemented in the JSON files to the Azure environment, i.e. if a JSON file is newly created/updated/deleted, the pipeline will create/update/delete the Policy and/or Initiative definition in Azure. If there are no changes, the pipeline can be run any number of times, as it won't make any changes to Azure.

In addition to the [common parameters](#common-parmeters-for-flexible-and-unified-definitions), these parameters are defined:

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Required | Selects the tenant, rootScope, defaultsubscription, assignment scopes and file names. If omitted, interactively prompts for the value. |
| `IncludeResource GroupsForAssignments` | Optional | Resource Group level assignments are not recommended; therefore, the script excludes Resource Groups from processing to save substantial execution time (tens of minutes to hours). This switch parameter overrides that default behavior. |
| `SuppressDeletes` | Optional | When using this switch, the script will NOT delete extraneous Policy definitions, Initiative definitions and Assignments. This can be useful for brown field deployments. |
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |
| `PolicyDefinitions` <br/> `RootFolder`| Optional | Root folder for Policy Definitions. Default: `./Definitions/Policies`. |
| `InitiativeDefinitions` <br/> `RootFolder` | Optional | Root folder for Initiative Definitions. Default: `./Definitions/Initiatives`. |
| `AssignmentsRootFolder` | Optional | Root folder for Assignment Files. Default: `./Definitions/Assignments`. |
| `PlanFile` | Optional | Plan output file (Json). Plan output filename. If empty it is read from `GlobalSettingsFile`. |

<br/>[Back to top](#pipeline)<br/>

### Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1

Deploys Policies, Initiatives, and Policy Assignments at their desired scope based on the plan. It completes the role assignment plan by adding needed Managed Identities.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PlanFile` | Optional | Plan input file (Json). Default: `./Output/Plans/current.json`. |
| `RolesPlanFile` | Optional | Role Assignment Plan output file (Json). Default: `./Output/Plans/roles.json`. |

<br/>[Back to top](#pipeline)<br/>

### Set-AzPolicyRolesFromPlan.ps1

Creates the role assignments for the Managed Identies required for `DeplyIfNotExists` and `Modify` Policies.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PlanFile` | Optional | Plan input file (Json). Default: `./Plans/roles.json`. |

<br/>[Back to top](#pipeline)<br/>

## Pipeline Execution

Upon `commit to a feature branch or a manual pipeline run`, the pipeline runs stage devAllStage to deploy Policies, Initiatives and Assignments to the PAC DEV environment. Second, it calculates the plan for PROD environment deployment based on the Feature branch. This plan is never executed. Instead the logs and if desired the artifact generated are used by the developer to verify the definition files and to determine if the code is ready for a Pull Request. The PR approver(s) will use the same input plus the source code changes to decide the PR approval or rejection.

![image.png](../Docs/Images/Commit.png)

<br/>

After the `pull request is approved and merged`, the pipeline runs stage devAllStage to deploy Policies, Initiatives and Assignments to the PAC TEST environment. Second, it calculates the plan for PROD environment deployment based on the merged Main branch. This plan is executed in one or two stages. The pipeline stops for PROD gate(s) approval at this time. The logs and if desired the artifacts generated are used by the PROD gate(s) approver(s) to decide on the PROD stage approval(s) or rejection(s).

![image.png](../Docs/Images/ApprovalGate.png)
![image.png](../Docs/Images/PreApprovalGate.png)

<br/>

Once the `approval gate is passed` deployments to prod will begin. Depending on the configuration a second approval before role assignments will be configured.

![image.png](../Docs/Images/FinalDeployment.png)

<br/>

If there are no changes, empty stage(s) are executed to explicitly show that no changes are needed. These stages do not need service connections or approvals.

![image.png](../Docs/Images/ProdNoChanges.png)

<br/>[Back to top](#pipeline)<br/>

## Reading List

1. **[Pipeline](#pipeline)**

1. **[Update Global Settings](../Definitions/README.md)**

1. **[Create Policy Definitions](../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../Definitions/Assignments/README.md)**

1. **[Scripts](../Scripts/README.md)**

**[Return to the main page](../README.md)**
<br/>[Back to top](#pipeline)<br/>
