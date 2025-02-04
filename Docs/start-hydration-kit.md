# EPAC Hydration Kit

The EPAC Hydration Script is intended to accelerate onboarding of EPAC as a policy management solution. It contains a growing number of common functions that are undertaken during deployment, and some functions that can be used later as needed. The scope of the initial Install-HydrationEpac command is to build a working repo from which to begin CLI based deployment, and place files for a basic deployment workflow. The pipeline files, as well as the pipeline environment, must be updated outside of this installer.

**The exact list of available commands can be retrieved by running the PowerShell script below.**

```PowerShell
Get-Command -module EnterprisePolicyAsCode | Where-Object {$_.Name -like "*-Hydration*"}
```

## Pre-requisites

The following software is required to use the EPAC Hydration Kit:

1. PowerShell Core
1. Az Module for PowerShell
1. EnterprisePolicyAsCode Module for PowerShell
1. Accounts with access to Azure for testing as outlined in [Deployment Scripts Section of the Index](index.md)
1. The Hydration Kit must be run by a Principal with the following abilities:
    1. All rights needed for the EPAC Dev account in the link above
    1. The ability to create Management Groups at the Tenant Root Level

> [!Note]
> To confirm that the necessary rights are available to the current service principal, create a new management group at tenant root and assign a policy to it. If the principal is unable to do these things, the script will not work.

## Deployment

The code below is an example of how the new set of functions can be leveraged to create a new EPAC deployment capable of managing policy via command line locally. This downloads the repo, places the StarterKit in the current Repo, and cleans up the rest of the download so that the module can be used. Script based deployment is not currently supported.

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

This will present you with a series of questions that will generate an output file that should be kept handy for reuse (some errors can be recovered by rerunning the process, such as access errors) and also for troubleshooting purposes. These answers will be used to generate a new EPAC repo from the root of the directory that the command is executed from.

## Next Steps

- This content must also be uploaded  to a repo and configure the repo to leverage the newly deployed pipelines.
- [Start the Enterprise Policy as Code (EPAC) Implementation](start-implementing.md) outlines the steps needed to complete the installation
  - The current process completes the steps **prior to** *Populate your Definitions folder with Policy resources*
  - The current process completes most of the steps **in** *Populate your Definitions folder with Policy resources*, see Current Functionality below for details.
- [CI/CD Overview](ci-cd-overview.md) provides insight into how to continue with the configuration of your DevOps Platform for ongoing EPAC CI/CD deployment, which is the next major area of focus.

Once your content is populated, it is time to test your deployment against the epac-dev Management Group hierarchy that was created as part of the deployment process.

```PowerShell
Build-DeploymentPlans  -PacEnvironmentSelector epac-dev
Deploy-PolicyPlan -PacEnvironmentSelector epac-dev
Deploy-RolesPlan -PacEnvironmentSelector epac-dev
```

While these represent early steps to managing EPAC via pipeline, they are not the last steps.

## Current Functionality

There are a growing number of deployment features that are available for rapid deployment.

1. Create Definitions directory structure
1. Populate basic flow pipelines from StarterKit for GitHub and Azure DevOps
1. Apply MCSB policySet from StarterKit for auditing purposes
1. (Optional) Apply PCI-DSS v4 policySet from StarterKit for auditing purposes
1. (Optional) Apply NIST 800-53 and Microsoft ASB policySets from StarterKit for auditing purposes
1. (Optional) Generate Caf3 Hierarchy to support secure by default deployment
1. (Optional) Add a list of policies and policySets to...
    1. Generate assignments for the primary pacSelector as well as the epac-dev pacSelector
    1. Generate default values for new assignments where possible
    1. Notify you of parameters that did not contain default settings and will require review
    1. Import into Definitions directory structure for processing in EPAC deployments
1. Process existing policy assignments
    1. Export for use in new repo under EPAC management
    1. Update with epac-dev pacSelector
        1. Resilient against non-management group assignments that cannot be replicated in epac-dev
    1. Import into Definitions directory structure for processing in EPAC deployments
1. Create duplicate of *Tenant Intermediate Group* Hierarchy with prefix and/or suffix for epac-dev processing

## Next Steps

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

### Install-Hydration Epac

1. Add Sync-AlzPolicies

### Additional Installation Workflows

1. Configure Roles and User Managed Identities/Service Principals
1. Configure Github repo/actions/environments/secrets/settings
    1. Release flow and configure pipeline moved to this process, kept basic flow until this process is ready
1. Configure ADO repo/pipelines/environments/secrets/settings
    1. Release flow and configure pipeline moved to this process, kept basic flow until this process is ready
