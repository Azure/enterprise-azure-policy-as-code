# Pipeline Operations

This article of the Policy as Code documentation contains all of the necessary information to run and operate the deployment pipeline properly. This repository contains a single `pipeline.yml` file that needs to be configured for your specific Azure environment.
The diagram below represents an overview of the pipeline deployment process for a multi-tenant configuration. Single tenant pipeline configurations will only have the prod tenant deployment.

![image.png](./images/PipelineOverview.png)

The components required for **configuring the pipeline and deploying policies, initiatives, and assignments** are the following:

| Component | What is it used for? | Where can it be found? |
|--|--|--|
| **Pipeline File** | The 'pipeline.yml' file is used to configure the deployment pipeline in Azure DevOps | In the `Pipeline` folder. |
| **Service Connections** | Service connections give the pipeline the proper permissions to deploy at desired Azure scopes | You must create these, refer to the following documentation:  https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml |
| **Desired Scope** | Desired scope is defined by your organization. It is recommended that you create 3 service connections (PROD, QA, DEV) | Refer to the quick start guide to see a breakdown of the recommended scopes to deploy to |
| **Deployment Scripts** | These scripts are used to deploy your policies, initiatives, and assignments to Azure | In the `Scripts` folder of this repository |

## Configuring the pipeline
> **NOTE**: Before configuring the pipeline, you will need to create service connections. Refer to the **[Quick Start Guide](../ReadMe.md)** for the permissions that need to be granted to each one.

You must edit the following items in the `pipeline.yml` file to align with your Azure environment
 - tenantID such as `12345678-1234-1234-1234-123456789012`
 - rootScope definitions per environment such as `/subscriptions/12345678-1234-1234-1234-123456789012` or `/providers/Microsoft.Management/managementGroups/12345678-1234-1234-1234-123456789012`
 - Service connection names such as `Policy-as-Code-DEV-Connection`

## Operating the pipeline

The pipeline operates in three consecutive steps in order to deploy policies, initiatives and assignments. This pipeline consists of six different stages that are triggered on the following four conditions:
- `Commit to feature branch OR manual pipeline run from feature branch`
- `Approval of a pull request OR manual pipeline fun from the main branch`
- `Final approval gate passing`

See the logical flow of the pipeline below:
- Upon `commit to a feature branch or a manual pipeline run`, the pipeline will run the Dev stage and deploy to the Dev scope as configured in the pipeline file. It will also create an initial plan of what changes will occur. This plan output is designed to be used by the person approving the pull request to analyze what changes are happening.

![image.png](./images/FiveStageCommit.png)

- After the `pull request is approved`, the QA stage will begin. This will deploy to your defined QA scope automatically, but will NOT deploy to your defined prod scope until the `approval gate is passed`. The approval gate is typically configured so that it can only be approved by someone other than the person who approved the pull request. This is approved separately from the pull request.

![image.png](./images/5StagePRapproval.png)

- Once the QA stage has finished, the deployment is ready for the final approval gate. The final approver can analyze any changes during this interval. Once the `approval gate is passed` deployments to prod will begin.

![image.png](./images/ApprovalGate.png)
![image.png](./images/5StageFinalDeployment.png)

## Next steps
Read through the rest of the documentation and configure the pipeline to your needs.

- **[Definitions](./Definitions.md)**
- **[Assignments](./Assignments.md)**
- **[Scripts and Configuration Files](./ScriptsAndConfigurationFiles.md)**
- **[Quick Start guide](../readme.md)**

[Return to the main page.](../readme.md)