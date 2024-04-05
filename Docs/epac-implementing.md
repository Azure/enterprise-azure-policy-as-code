# Implementing Enterprise Policy as Code

!!! danger "Caution"

    EPAC is a true desired state deployment technology. It takes possession of all Policy Resources at the `deploymentRootScope` and its children. It will **delete any Policy resources not defined in the EPAC repo**. This behavior can be modified as documented in the [desired state strategy](desired-state-strategy.md) page.

## Getting Started

The following steps are required to implement Enterprise Policy as Code (EPAC) in your environment:

1. Understand [concepts and environments](#epac-concepts-and-environments).
2. Determine [desired state strategy](settings-desired-state.md).
3. How to handle [Defender for Cloud Policy Assignments](settings-dfc-assignments.md).
7. Design your [CI/CD process](ci-cd-overview.md).
4. Install [Powershell and EPAC](#install-powershell-and-epac).
5. Create your [`Definitions` folder and subfolders](#create-the-definitions-folder).
6. Populate `global-settings.jsonc` with your [environment settings](settings-global-setting-file.md) and [desired state strategy](settings-dfc-assignments.md).
7. Populate your Definitions folder with Policy resources.
    - [Option A:] [Extract existing Policy resources](epac-extracting-policy-resources.md) from your Azure environment.
    - [Option B:] [Integrate Azure Landing Zones (ALZ)](integrating-with-alz.md).
    - [Option C:] Utilize the [hydration kit](operational-scripts-hydration-kit.md) and `StarterKit` content.
    - [Optional] Create custom [Policy definitions](policy-definitions.md).
    - [Optional] Create custom [Policy Set definitions](policy-set-definitions.md).
    - Create your [Policy Assignments](policy-assignments.md).
    - [Optional] Manage [Policy Exemptions](policy-exemptions.md).
8. Implement your [CI/CD pipelines](ci-cd-overview.md).
8. Operate your environment with the provided [operational scripts](operational-scripts.md).

## EPAC Concepts and Environments

!!! success "Important"

    Understanding the concepts and  environments is crucial. Do **not** proceed until you completely understand this section.

### EPAC Concepts

Like any other code development project (including Infrastructure as Code - IaC), developing Policy requires a development area to test and validate the Policy resources before deploying them to production. EPAC is no different.

- EPAC's nonprod environment is used to develop and test Policy resources. In most cases you will need one management group hierarchy to simulate EPAC production tenants and management groups for development and testing of Policy definitions and Policy Assignments.
- EPAC's prod environment will govern all other IaC environments (e.g., sandbox, development, integration, test/qa, pre-prod, prod, ...) and tenants. This can be confusing. We will use **EPAC environments** and **IaC environments** to disambiguate the environments.

### Defining EPAC Environments

EPAC defines environments identified by a string (unique per repository) called `pacSelector`. `pacEnvironments` in `global-settings.jsonc` environment map a `pacSelector` to the following settings:

- `cloud` - to select commercial or sovereign cloud environments.
- `tenantId` - enables multi-tenant scenarios.
- `rootDefinitionScope` - scope for custom Policy and Policy Set definition deployment.
- [Optional] Define the following items:
  - `globalNotScopes` - used to exclude scopes from Policy Assignments.
  - `managedIdentityLocations` - used for the location for created Managed Identities.
  - `desiredState` - desired state strategy and details for Policy resources.
  - `managedTenant` - used for environments that are in a lighthouse managed tenant.

These associations are stored in [global-settings.jsonc](settings-global-setting-file.md) in an element called `pacEnvironments`.

### Multi-Tenant Support

EPAC supports single and multi-tenant deployments from a single source. In most cases you should have a fully or partially isolated area for Policy development and testing, such as a Management Group. An entire tenant can be used; however, it is not necessary since EPAC has sophisticated partitioning capabilities.  EPAC also supports deployments to managed (Lighthouse) tenants and is able to deploy cross tenant role assignments to projected subscriptions in order to facilitate writing data back to the managing tenant (e.g. diagnostic settings).

### Example Management Group Structure and EPAC Environments

Assuming that you have a single tenant with a management group hierarchy as follows (with additional levels of management groups not shown for brevity):

- Root tenant (always present)
  - mg-Enterprise (pseudo root)
    - mg-Identity
    - mg-NonProd
      - mg-Dev
      - mg-Sandbox
      - ...
    - mg-Prod
      - mg-LandingZones
      - mg-PCI
    - mg-EpacDev (EPAC development)

You should create a development testing structure for EPAC in `mg-EpacDev`. We have found little need for a separate management group for EPAC testing, but you can create one mirroring the structure of `mg-EpacDev`.

- Root tenant (always present)
  - mg-Enterprise (pseudo root) :arrow_right: **EPAC environment `"tenant"`**
    - mg-Identity
    - mg-NonProd
    - mg-Sandbox
    - mg-Prod
    - mg-PCI
    - mg-EpacDev (EPAC development) :arrow_right: **EPAC environment `"epac-dev"`**
      - mg-EpacDev-Identity
      - mg-EpacDev-NonProd
        - mg-EpacDev-Dev
        - mg-EpacDev-Sandbox
      - mg-EpacDev-Prod
        - mg-EpacDev-LandingZones
        - mg-EpacDev-PCI

The simplest `global-settings.jsonc` for the above structure is:

```json
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json",
    "pacOwnerId": "{{guid}}",
    "pacEnvironments": [
        {
            "pacSelector": "epac-dev",
            "cloud": "AzureCloud",
            "tenantId": "{{tenant-id}}",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/mg-Epac-Dev"
        },
        {
            "pacSelector": "tenant",
            "cloud": "AzureCloud",
            "tenantId": "{{tenant-id}}",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/mg-Enterprise"
        }
    ]
}
```

## Cloud Environment with Unsupported/Missing Policy Definitions

In some multi-tenant implementations, not all policies, policy sets, and/or assignments will function in all tenants, usually due to either built-in policies that don't exist in some tenant types or unavailable resource providers.  In order to facilitate multi-tenant deployments in these scenarios, utilize the `epacCloudEnvironments` property to specify which cloud type a specific file should be considered in.  For example in order to have a policy definition deployed only to epacEnvironments that are China cloud tenants, add a metadata property like this to that definition (or definitionSet) file:

```json
"metadata": {
  "epacCloudEnvironments": [
    "AzureChinaCloud"
  ]
},
```

For assignment files, this is a top level property on the assignment's root node:

```json
"nodeName": "/root",
"epacCloudEnvironments": [
    "AzureChinaCloud"
],
```


## Install Powershell and EPAC

EPAC can be installed in two ways:

- Install the `EnterprisePolicyAsCode` module from the [PowerShell marketplace](https://www.powershellgallery.com/packages/EnterprisePolicyAsCode). This is the recommended approach documented here.
- Copy the source code from an [EPAC GitHub repository fork](https://github.com/Azure/enterprise-azure-policy-as-code). The process is described in [Forking the GitHub Repo - an Alternate Installation Method](fork-github.md) page.

### Installation Steps

1. [Install PowerShell 7.4 or later](https://github.com/PowerShell/PowerShell/releases).
2. Install the Az PowerShell modules and Enterprise Policy as Code module.
```ps1
    Install-Module Az -Scope CurrentUser
    Install-Module EnterprisePolicyAsCode -Scope CurrentUser
```

Many scripts use parameters for input and output folders. They default to the current directory. We recommend that you do one of the following approaches instead of accepting the default to prevent your files being created in the wrong location:
    - [Preferred] Set the environment variables `PAC_DEFINITIONS_FOLDER`, `PAC_OUTPUT_FOLDER`, and `PAC_INPUT_FOLDER`.
    - [Alternative] Use the script parameters `-DefinitionsRootFolder`, `-OutputFolder`, and `-InputFolder`.

### `Definitions` Folder Structure

- Define the Azure environment(s) in file `global-settings.jsonc`
- Create custom Policies (optional) in folder `policyDefinitions`
- Create custom Policy Sets (optional) in folder `policySetDefinitions`
-  efine the Policy Assignments in folder `policyAssignments`
- Define the Policy Exemptions (optional) in folder `policyExemptions`
- Define Documentation in folder `policyDocumentations]`

### Create the Definitions folder

Create a new EPAC `Definitions` folder with a number of subfolder and a `global-settings.jsonc` file

```ps1
New-EPACDefinitionFolder -DefinitionsRootFolder Definitions
```

## Debug EPAC issues

Should you encounter issues with the expected behavior of EPAC, try the following:

* Run the scripts interactively.
* [Debug the scripts in VS Code](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/using-vscode?view=powershell-7.3).
* Ask for help by raising a [GitHub Issue](https://github.com/Azure/enterprise-azure-policy-as-code/issues/new)
