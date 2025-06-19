# Integrating EPAC with the Azure Landing Zones Library (New)

## Pre-requisites

To use the ALZ policies in an environment successfully there are some Azure Resources that need to be created. This is normally completed by using one of the ALZ accelerators to deploy the environment however if you have written your own code or modified the default deployment ensure you have the following resources in place to support the ALZ policies.

- Log Analytics workspace
- DCR rules to support monitoring - [data collection rule templates](https://github.com/Azure/Enterprise-Scale/tree/main/eslzArm/resourceGroupTemplates)
- User Assigned Managed Identity to support Azure Monitor Agent - [sample template](https://github.com/Azure/Enterprise-Scale/blob/main/eslzArm/resourceGroupTemplates/userAssignedIdentity.json)

## Using the new Azure Landing Zone Library sync process

### Create a policy default structure file

This file contains information that drives the sync process. The file includes management group IDs, default enforcement mode, and parameter values. **It must be generated at least once before executing the sync process.**

1. Ensure that the EPAC module is up to date - required minimum version to use these features is 10.9.0.
2. Use to code to clone the library repository and create the default file. There are examples below on how to run this commnand - you will only need to run one of these depending on your requirements.

```ps1
# Create a Pac Environment default file for ALZ policies using the latest version of the ALZ Library 
New-ALZPolicyDefaultStructure -DefinitionsRootFolder .\Definitions -Type ALZ -PacEnvironmentSelector "epac-dev"

# Create a default file for ALZ policies specifiying a tagged version of the ALZ Library 
New-ALZPolicyDefaultStructure -DefinitionsRootFolder .\Definitions -Type ALZ -Tag "platform/alz/2025.02.0"

# Create a default file for ALZ policies by provising a path to a cloned/modified library 
New-ALZPolicyDefaultStructure -DefinitionsRootFolder .\Definitions -Type ALZ -LibraryPath <<path to library>>

# Create a default file for AMBA policies using the latest version of the ALZ Library 
New-ALZPolicyDefaultStructure -DefinitionsRootFolder .\Definitions -Type AMBA
```

3. The file generated contains a representation of a management group structure, enforcement mode settings and required default parameter values. Update these values to match your environment.

An example of where to update a parameter

```json
"ama_vm_insights_data_collection_rule_id": {
      "policy_assignment_name": [
        "Deploy-VM-Monitoring",
        "Deploy-VMSS-Monitoring",
        "Deploy-vmHybr-Monitoring"
      ],
      "description": "The data collection rule id that should be used for the VM Insights deployment.",
      "parameters": {
        "parameter_name": "dcrResourceId",
        "value": "" // Update the value here as required by the description
      }
    }
```

An example of where to update a management group ID

```json
"management": {
      "management_group_function": "Management",
      "value": "/providers/Microsoft.Management/managementGroups/management" //replace with your management group ID
    },
```

Modify the default enforcement mode

```json
"enforcementMode": "Default" // Can be Default or DoNotEnforce
```

### Sync with ALZ Policy Repo

The next command will generate policy assignments based on the values in this file so ensure they are correct for your environment.

1. Use to code to sync the policy files and update scopes and parameters based on the information in the previously created file. There are examples below on how to run this command - you will only need to run one of these depending on your requirements. The files will be copied into their own folder to separate them from any definitions already in the repository.

```ps1
# Sync the ALZ policies and assign to the "epac-dev" PAC environment.
Sync-ALZPolicyFromLibrary -DefinitionsRootFolder .\Definitions -Type ALZ -PacEnvironmentSelector "epac-dev"

# Sync the ALZ policies and assign to the "epac-dev" PAC environment. Specify a tagged version of the ALZ library
Sync-ALZPolicyFromLibrary -DefinitionsRootFolder .\Definitions -Type ALZ -PacEnvironmentSelector "epac-dev" -Tag "platform/alz/2025.02.0"

# Sync the ALZ policies from a cloned/modified library
Sync-ALZPolicyFromLibrary -DefinitionsRootFolder .\Definitions -Type ALZ -PacEnvironmentSelector "epac-dev" -LibraryPath <<path to library>>

# Sync the AMBA policies and assign to the "epac-dev" PAC environment.
Sync-ALZPolicyFromLibrary -DefinitionsRootFolder .\Definitions -Type AMBA -PacEnvironmentSelector "epac-dev"
```

Carefully review the generated policy assigments and ensure all parameter and scope information is correct.

2. When complete run `Build-DeploymentPlans` to ensure the correct changes are made. During the first sync for either a new or existing environment there will be many changes due to updating of the existing policies.

## Examples

### ALZ

```ps1
# Create a Pac Environment default file for ALZ policies using the latest version of the ALZ Library 
New-ALZPolicyDefaultStructure -DefinitionsRootFolder .\Definitions -Type ALZ -PacEnvironmentSelector "epac-dev"

# Sync the ALZ policies and assign to the "epac-dev" PAC environment.
Sync-ALZPolicyFromLibrary -DefinitionsRootFolder .\Definitions -Type ALZ -PacEnvironmentSelector "epac-dev"
```

### AMBA (ALZ)

For users interested in deploying the [Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/welcome/) project with EPAC - these policies have been extracted and converted to the EPAC format and are available at the [amba-export](https://github.com/anwather/amba-export) repository.

> [!Note]
> It is recommeneded to review breaking changes on the [AMBA Releases](https://azure.github.io/azure-monitor-baseline-alerts/patterns/alz/HowTo/UpdateToNewReleases/) page to avoid unexpected failed policy deployments. In most cases, it's an update of a parameter type (i.e. String -> Array).

```ps1
# Create a Pac Environment default file for AMBA policies using the latest version of the ALZ Library 
New-ALZPolicyDefaultStructure -DefinitionsRootFolder .\Definitions -Type AMBA -PacEnvironmentSelector "epac-dev"

# Sync the AMBA policies and assign to the "epac-dev" PAC environment.
Sync-ALZPolicyFromLibrary -DefinitionsRootFolder .\Definitions -Type AMBA -PacEnvironmentSelector "epac-dev"
```

### SLZ

For users interested in deploying the [Sovereignty Policy Baseline](https://github.com/Azure/sovereign-landing-zone/blob/main/docs/scenarios/Sovereignty-Baseline-Policy-Initiatives.md) project with EPAC - these policies have been extracted and converted to the EPAC format and are available at the [spb-export](https://github.com/anwather/spb-export) repository.

```ps1
# Create a Pac Environment default file for SLZ policies using the latest version of the ALZ Library 
New-ALZPolicyDefaultStructure -DefinitionsRootFolder .\Definitions -Type SLZ -PacEnvironmentSelector "epac-dev"

# Sync the SLZ policies and assign to the "epac-dev" PAC environment.
Sync-ALZPolicyFromLibrary -DefinitionsRootFolder .\Definitions -Type SLZ -PacEnvironmentSelector "epac-dev"
```

## Advanced Scenarios

Using the format of the Azure Landing Zones repository it is possible to extend the management groups defined and provide your own archetypes. You must maintain a local copy of the library for this purpose. Details will be provided at a later stage on how to customize this for different scenarios including:

- Modifying the management group structure (add new groups and archetypes)
- Add/Remove policies from an archetype

### Maintaining multiple ALZ/AMBA environments

If you need to have separate parameter values or different management group names for different PAC environments you can follow steps below.

1. Generate a policy structure file using `New-ALZPolicyDefaultStructure` and specify the `-PacEnvironmentSelector` parameter.

This generates a standard file structure however the file's name will now include the Pac Selector given. This default structure will now be used everytime you run the "Sync-ALZPolicyFromLibrary" command with the matching PacEnvironmentSelector.

For example: -

```
alz.policy_default_structure.<PAC SELECTOR>.jsonc
```

2. When syncing policies run the `Sync-ALZPolicyFromLibrary` once for each PAC Environment. A folder specific for that Pac Selector will now be placed within the ALZ Type.

### Disabling / Changing specific parameters

If you need to disable a single policy parameter, such as the 'effect' for a specific policy within an assignment, add that parameter to your default file structure to ensure it is not overwritten when running the **Sync-ALZPolicyFromLibrary** command.

An example of disabling the **"Configure Microsoft Defender for Key Vault plan"** in the **"Deploy-MDFC-Config-H224"** Policy Assignment.

```json
"enableAscForKeyVault_effect": {
      "policy_assignment_name": [
        "Deploy-MDFC-Config-H224"
      ],
      "description": "Enable or disable the execution of the Key Vault DFC policy.",
      "parameters": {
        "parameter_name": "enableAscForKeyVault",
        "value": "Disabled" // Update the value here as required by the description
      }
    }
```