# Azure DevOps Pipelines

This page covers the specifics for the Azure DevOps (ADO) pipelines created by using the Starter Kit. Pipelines can be further customized based on requirements. Guidance provided is for the simplified GitHub Flow as documented in the [branching flows](ci-cd-branching-flows.md). Documentation on the Release Flow pipelines will be made available in a future release.

> [!Note]
> To find all examples of Azure DevOps Pipelines, please visit [StarterKit/Pipelines/AzureDevOps](https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit/Pipelines/AzureDevOps).

> [App Registration Setup](ci-cd-app-registrations.md) is a pre-requisite.

## Service connections for the Service Principals

Create ADO service connections for each of the previously created [App Registrations](ci-cd-app-registrations.md). You will need to retrieve the credential for the Service Principal that Azure Devops will use for Authentication. This can be either a Client Secret, a X509 certificate, or a Federated Credential. For more information on these options, refer to the [Application Credentials](ci-cd-app-registrations.md/#application-credentials).

## Pipeline Templates

The provided Azure DevOps pipelines utilize the template functionality to create re-usable components that are shared between pipeline files. More details on Azure DevOps Pipelines Templates can be found in the [Azure DevOps Documentation](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops&pivots=templates-includes)

## GitHub Flow Pipeline

If utilizing the GitHub flow branching strategy, three pipeline files are created

- [epac-dev-pipeline](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/StarterKit/Pipelines/AzureDevOps/GitHub-Flow/epac-dev-pipeline.yml)
- [epac-tenant-pipeline](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/StarterKit/Pipelines/AzureDevOps/GitHub-Flow/epac-tenant-pipeline.yml)
- [epac-remediation-pipeline](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/StarterKit/Pipelines/AzureDevOps/GitHub-Flow/epac-remediation-pipeline.yml)

### epac-dev-pipeline

This represents the Develop Policy Resources in a Feature Branch flow as described in [Branching Flows](ci-cd-branching-flows.md/#develop-policy-resources-in-a-feature-branch). In general, The EPAC-Dev pipeline is configured to run when any change is pushed to a `feature/*` branch. It runs across three (3) stages: Plan, Deploy & Tenant Plan.

### epac-tenant-pipeline

This represents the Simplified `GitHub Flow` for Deployment as described in [Branching Flows](ci-cd-branching-flows.md/#simplified-`github-flow`-for-deployment). In general, The epac-tenant-pipeline is configured to run when any change is pushed to main and runs across three (3) stages: Plan, Deploy Policy & Deploy Roles. The Deploy stages utilize [Azure DevOps environments](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments?view=azure-devops) to configure approval gates

### epac-remediation-pipeline

This pipeline runs on a schedule to automatically start remediation tasks for each environment.
