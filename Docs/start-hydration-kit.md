# EPAC Hydration Kit

> [!WARNING]
> The EPAC Hydration Kit is in beta, please report bugs as they are found.

> [!WARNING]
> Known Bug: Use of the Branching Flow option *release* will require manual updates to the NONPROD assignments, and a manual creation of an exclusion in the PROD scope if that NONPROD management group is part of the PROD hierarchy, such as in the CAF3 SANDBOX Management Group.

The EPAC Hydration Script is intended to accelerate onboarding of EPAC as a policy management solution. It contains a growing number of common functions that are undertaken during deployment, and some functions that can be used later as needed. The exact list of available commands can be retrieved by running the PowerShell script below.

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
> If you plan to only read and deploy at a lower management group, you can replace Tenant Root with that Management Group for the purposes of this documentation.

## Deployment

The code below is an example of how the new set of functions can be leveraged to create a new EPAC deployment capable of managing policy via command line locally. This downloads the repo, places the StarterKit in the current Repo, and cleans up the rest of the download so that the module can be used. Script based deployment is not currently supported.

```PowerShell
$myRepoRoot = "/Path/To/Local/Root/Of/New/Repo"
Set-Location $myRepoRoot
git clone https://github.com/Azure/enterprise-azure-policy-as-code.git ./temp
Copy-Item ./temp/StarterKit ./StarterKit -Recurse
Install-Module EnterprisePolicyAsCode
Import-Module EnterprisePolicyAsCode
Remove-Item ./temp -Force -Recurse
Connect-AzAccount
Install-HydrationEpac
```

This will present you with a series of questions that will generate an output file that should be kept handy for reuse (some errors can be recovered by rerunning the process, such as access errors) and also for troubleshooting purposes. These answers will be used to generate a new EPAC repo from the root of the directory that the command is executed from.

The next recommended step is to test your deployment against the epac-dev Management Group hierarchy that was created as part of the deployment process.

```PowerShell
Build-DeploymentPlans  -PacEnvironmentSelector epac-dev
Deploy-PolicyPlan -PacEnvironmentSelector epac-dev
Deploy-RolesPlan -PacEnvironmentSelector epac-dev
```

While these represent early steps to managing EPAC via pipeline, they are not the last steps.

## Next Steps

- This content must also be uploaded  to a repo and configure the repo to leverage the newly deployed pipelines.
- [Start the Enterprise Policy as Code (EPAC) Implementation](start-implementing.md) outlines the steps needed to complete the installation
  - The current process completes the steps **prior to** *Populate your Definitions folder with Policy resources*
  - The current process completes most of the steps **in** *Populate your Definitions folder with Policy resources*, see Current Functionality below for details.
- [CI/CD Overview](ci-cd-overview.md) provides insight into how to continue with the configuration of your DevOps Platform for ongoing EPAC CI/CD deployment, which is the next major area of focus.

## Current Functionality

There are a growing number of deployment features that are available for rapid deployment.

1. Create Definitions directory structure
1. Populate pipelines from StarterKit
1. Apply PCI-DSS v4 policySet from StarterKit for auditing purposes
1. Apply NIST 800-53 and Microsoft ASB policySets from StarterKit for auditing purposes
1. Existing Policy Assignments
    1. Export for use in new repo
    1. Update with epac-dev pacSelector
        1. Is resilient against non-management group assignments that cannot be replicated in epac-dev
    1. Import into Definitions directory structure for processing in EPAC deployments
1. Create duplicate of *Tenant Intermediate Group* Hierarchy with prefix and/or suffix for epac-dev processing

## Upcoming Roadmap Items

1. Automatically consolidate regulatory auditing assignments if multiple are chosen from StarterKit
1. Automatically consolidate all policySet csv sources into a main file, and update the referenced filename, as part of import from StarterKit.
1. Repair bug regarding release branch flow
    1. Build logic to process multiple child nodes
    1. Build logic to process multiple non-epac pacSelectors
    1. Build logic to differentiate new pacSelector and new childNode
    1. Build logic to generate new pacSelectors and childNodes
1. Add Sync-AlzPolicies
    1. Build logic to gather and confirm resources that are needed to support this
1. Add remaining StarterKit content to import choices
1. Configure Roles and User Managed Identities/Service Principals
1. Configure Github repo/actions/environments/secrets/settings
1. Configure ADO repo/pipelines/environments/secrets/settings
