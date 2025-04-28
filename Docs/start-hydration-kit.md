# EPAC Hydration Kit

The EPAC Hydration Script is intended to accelerate onboarding of EPAC as a policy management solution. It contains a growing number of common functions that are undertaken during repo deployment, and some functions that can be used later as needed. The scope of the initial Install-HydrationEpac command is to build a working repo from which to begin CLI based deployment. The pipeline files, as well as the pipeline environment, must be populated and updated outside of this installer.

**The exact list of available commands can be retrieved by running the PowerShell script below.**

```PowerShell
Get-Command -module EnterprisePolicyAsCode | Where-Object {$_.Name -like "*-Hydration*"}
```

## Pre-requisites

The following software is required to use the EPAC Hydration Kit:

1. PowerShell Core
1. Az Module for PowerShell
1. EnterprisePolicyAsCode Module for PowerShell
1. Accounts with access to Azure for testing as outlined in [Deployment Scripts Section of the Index](./index.md)
1. The Hydration Kit must be run by a Principal with the following abilities:
    1. All rights needed for the EPAC Dev account in the link above
    1. The ability to create Management Groups at the Tenant Root Level

> [!Note]
> To confirm that the necessary rights are available to the current service principal, create a new management group at tenant root.

## Repo Creation

The code below is an example of how the new set of functions can be leveraged to create a new EPAC deployment capable of managing policy via command line locally. As part of the installation process, the StarterKit folder will be populated in the repo by default. Other items will be populated based on the choices made.

```PowerShell
$tenantId = "YourTenantGuid"
$tenantIntermediateRoot = "YourTenantIntermediateRootManagementGroupId"
$myRepoRoot = "/Path/To/Local/Root/Of/New/Repo"
Set-Location $myRepoRoot
Install-Module EnterprisePolicyAsCode
Import-Module EnterprisePolicyAsCode
Connect-AzAccount -TenantId $tenantId
Install-HydrationEpac -TenantIntermediateRoot $tenantIntermediateRoot
```

```PowerShell
# Example...
$tenantId = "00000000-nota-real-guid-000000000000"
$tenantIntermediateRoot = "mgNameNotDisplayName"
$myRepoRoot = "/home/myId/Documents/git/epac"
Set-Location $myRepoRoot
Install-Module EnterprisePolicyAsCode
Import-Module EnterprisePolicyAsCode
Connect-AzAccount -TenantId $tenantId
Install-HydrationEpac -TenantIntermediateRoot $tenantIntermediateRoot
```

This installer will present you with a series of questions that will generate an output file. This should be kept handy for reuse (some errors can be recovered by rerunning the process, such as access errors), as well as for troubleshooting purposes in the case of an unrecoverable error. These answers will be used to generate a new EPAC repo from the root of the directory that the command is executed from.

### Key Decisions

You will make decisions that will drive whether or not a number of operations occur.

1. Create the Tenant Intermediate Root management group to contain the management group hierarchy
1. Create a Management Group Structure based on CAF3 Model within the Tenant Intermediate Root
    1. This will generate a new structure based on the CAF3 Model with the basic Corp and Online Archetypes.
    1. These generally represent the traditional Internal and Perimeter Zones respectively, and while they do not represent the sum of useful Archetypes, they do generally represent the minimum number required to deploy with a Security First approach
1. Export the current set of policyAssignments in Azure
    1. This will not be useful in a greenfield environment as nothing has yet been assigned

> [!NOTE]
> While it is possible to both export policies from the management group structure and create it in the same step, it is rare that this is useful. Consider whether there is any content in this area to export when answering.

You will also make decisions that will drive configuration that is specific to this implementation of EPAC.

1. [pacOwnerId](./settings-global-setting-file.md) for this installation of EPAC
1. Name hash(es) for clone of Tenant Intermediate Root management group structure
    1. This prevents naming collisions between your environment and the EPAC environment used for deployment testing in the CI/CD pipeline
    1. Suffix offers an opportunity to leverage a standardized suffix for EPAC management group names (Example: epacDev-contosoTIR)
    1. Prefix offers an opportunity to leverage a standardized prefix for EPAC management group names (Example: contosoTIR-epacDev)
1. Management group hierarchy location for EPAC management groups
1. Location for managed IDs used by policies which leverage

Additional actions will be undertaken in order to facilitate the deployment of EPAC.

1. Download of the EPAC Starter Kit
1. Generate a Definitions folder
    1. Populate policyAssignments, policyDefinitions, and policySetDefinitions based on decisions made
    1. Create new assignments designated in the IPKit, as well as the Microsoft Cloud Security Baseline
        1. Export of current assignments, the optional list of additional assignments desired, and security standards questions will affect this
    1. Create new Definition content based on Export decisions

### Current Functionality

There are a growing number of deployment features that are available for rapid deployment.

1. Create Definitions directory structure
1. Decide on Script or Module based implementation
1. Update Assignments:
    1. Process existing policy assignments
        1. Export for use in new repo under EPAC management
        1. Update with epac-dev pacSelector
            1. Will not replicate non-management group assignments as subscriptions and below cannot be replicated programatically
    1. Add Compliance Assignments:
        1. Apply MCSB policySet from StarterKit for auditing purposes
        1. (Optional) Apply PCI-DSS v4 policySet from StarterKit for auditing purposes
        1. (Optional) Apply NIST 800-53 and Microsoft ASB policySets from StarterKit for auditing purposes
    1. (Optional) Add a list of built-in content to assign
        1. Generate assignments for the primary pacSelector as well as the epac-dev pacSelector
        1. Generate default values for new assignments where possible
        1. Notify you of parameters that did not contain default settings and will require review
        1. Import into Definitions directory structure for processing in EPAC deployments
1. Update Management Group Hierarchy:
    1. (Optional) Generate Caf3 Hierarchy to support secure by default deployment
        1. If this is chosen, there will be no need to export the current assignment set as there will be none present in the brand new hierarchy
    1. Create duplicate of *Tenant Intermediate Group* Hierarchy with prefix and/or suffix for epac-dev processing based on decisions made

### Limitations

While these are limitations to the Hydration Kit itself, they can be adressed manually after the initially Hydration Kit based deployment is complete. The intent of this program is to provide a prototype environment that can be used as a baseline for customization rather than to provide automation for all possible customizations.

1. Multiple Tenants cannot be automatically configured
1. Release Flow pacSelector cannot automatically be created
1. Update/Management of Workflows is outside the scope of the installer at this time

## Initial Test Deployment

Deploy to EPAC Development Environment Using CLI

<!-- - This content must also be uploaded  to a repo and configure the repo to leverage the newly deployed pipelines. -->
[Start the Enterprise Policy as Code (EPAC) Implementation](start-implementing.md) outlines the steps needed to complete the installation

- The current Install-HydrationKit process completes the steps **prior to** *Populate your Definitions folder with Policy resources*
- The current Install-HydrationKit process completes most of the steps **in** *Populate your Definitions folder with Policy resources*, detailed in [Current Functionality](#current-functionality)
- [CI/CD Overview](ci-cd-overview.md) provides insight into how to continue with the configuration of your DevOps Platform for ongoing EPAC CI/CD deployment, which is the next major area of focus.

Once your content is populated, it is time to test your deployment against the epac-dev Management Group hierarchy that was created as part of the deployment process.

```PowerShell
Build-DeploymentPlans  -PacEnvironmentSelector "epac-dev"
Deploy-PolicyPlan -PacEnvironmentSelector "epac-dev"
Deploy-RolesPlan -PacEnvironmentSelector "epac-dev"
```

> [!IMPORTANT]
> [Understanding the concepts and  environments](./start-implementing.md) is crucial. Do **not** deploy to environments other than epac-dev until you completely understand this content.

## Next Steps

The installer builds out the repo insofar as CLI based deployment using a highly privileged account. After this prototype is complete, it is necessary to move to a more secure configuration that can be automated and audited.

### Least Privilege: Custom Reader Role

This is an optional step that will create a custom role used in planning deployments that will provide the the least privilege necessary for the process.

`New-AzPolicyReaderRole` creates a custom role EPAC Resource Policy Reader with Id `2baa1a7c-6807-46af-8b16-5e9d03fba029`. It provides read access to all Policy resources for the purpose of planning the EPAC deployments at the scope selected with PacEnvironmentSelector. This role can be used to reduce the scope of the Service Principal used in the ```Build-PolicyPlans``` stage of the deployment process.

The permissions granted are:

- Microsoft.Authorization/policyassignments/read
- Microsoft.Authorization/policydefinitions/read
- Microsoft.Authorization/policyexemptions/read
- Microsoft.Authorization/policysetdefinitions/read
- Microsoft.Authorization/roleAssignments/read
- Microsoft.PolicyInsights/*
- Microsoft.Management/register/action
- Microsoft.Management/managementGroups/read
- Microsoft.Resources/subscriptions/read
- Microsoft.Resources/subscriptions/resourceGroups/read

## Create Azure DevOps Pipeline or GitHub Workflow

`New-PipelinesFromStarterKit` creates a new Azure DevOps Pipeline or GitHub Workflow from the starter kit. This script copies pipelines and templates from the starter kit to a new folder. The script assembles the pipelines/workflows based on the type of pipeline to create, the branching flow to implement, and the type of script to use.

`-StarterKitFolder <String>`

`-PipelinesFolder <String>`

`-PipelineType <String>` - AzureDevOps or GitHubActions; default is AzureDevOps

`-BranchingFlow <String>` - Release or GitHub (flow); default is Release

`-ScriptType <String>` - scripts (in your repo) or module (from PowerShell gallery); default is module

1. CI/CD Integration
    1. [General Guidance](https://azure.github.io/enterprise-azure-policy-as-code/ci-cd-overview/)
    1. [Branching Flow Guidance](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/ci-cd-branching-flows.md): Review high level CI/CD Options. While the hydration kit only supports a standard two stage deployment plan, you may want to consider a release plan for your environment.
    1. [Azure DevOps](https://azure.github.io/enterprise-azure-policy-as-code/ci-cd-ado-pipelines/): Review Azure DevOps Pipeline implementation options and guidance.
    1. [GitHub Actions](https://azure.github.io/enterprise-azure-policy-as-code/ci-cd-github-actions/): Review Github Actions implementation options and guidance.
1. Additional Policy Assignments
    1. [Sync-AlzPolicies](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/integrating-with-alz.md#scenario-2---alz-policy-deployment-with-epac): Import the ALZ Policy Set using Sync-AlzPolicies, and update the parameters which do not have default values to add policies that will aid in modification of your environment to baseline Microsoft standards.
    1. [Create Additional Assignments](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/operational-scripts.md)
    1. Review the command *Export-PolicyToEPAC* to simplify additional assignment creation.

## Upcoming Roadmap Items

### Install-HydrationEpac

1. Add Sync-AlzPolicies
1. Configure [Defender For Cloud Integration](./settings-dfc-assignments.md)
1. Generate Documentation for Compliance Assignments

### Additional Possible Future Installation Command Sets

Each of these sets is broken up by API usage to accomplish the task. As each will require a different framework, they are listed as separate initiatives.

1. Install-HydrationGithubRepo
    1. Configure Github repo/actions/environments/secrets/settings
        1. Release flow and configure pipeline moved to this process, kept basic flow until this process is ready
        1. Provide baseline security configuration
        1. Populate main branch
1. Install-HydrationAdoRepo
    1. Configure ADO repo/pipelines/environments/secrets/settings
        1. Flows: Release, Basic (github), Exemption, Remediation
        1. Provide baseline security configuration
        1. Populate main branch
