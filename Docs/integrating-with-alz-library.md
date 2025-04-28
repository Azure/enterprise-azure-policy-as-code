# Integrating EPAC with the Azure Landing Zones Library

The [Azure Landing Zones Library](https://azure.github.io/Azure-Landing-Zones-Library/) contains the source of all policy definitions, set definition and assignments for not only the Azure Landing Zone deployment but associated projects such as the Azure Monitor Baseline Alerts and Sovereign Landing Zone accelerator. Previous integration with EPAC involved manually updating the assignments provided and was complex and difficult to maintain.

This new method of maintaining and deploying the policies provides the following benefits: -

- One process for ALZ / AMBA / SLZ instead of separate processes.
- Pin to a version of the library by specifying a tag during sync - or refer to an already cloned copy.
- Modify the cloned repository to add new assignments, management group archetypes, parameters.
- A single file provides the default values for the policy assignments making it easier to maintain. Add new parameter values as required.

## Why and when should you use EPAC to manage ALZ deployed policies

EPAC can be used to manage Azure Policy deployed using ALZ Bicep or Terraform using the scenarios below. Some reasons you may want to switch to EPAC policy management include:

- You have existing unmanaged policies in a brownfield environment that you want to deploy in the new ALZ environment. [Export the existing policies](start-extracting-policy-resources.md) and manage them with EPAC alongside the ALZ policy objects.
- You have ALZ deployed in a non standard way e.g. multiple management group structures for testing, non-conventional management group structure. The default assignment structure provided by other ALZ deployment methods may not fit your strategy.
- A team that is not responsible for infrastructure deployment e.g. a security team may want to deploy and manage policies.
- You require features from policy not available in the ALZ deployments e.g. policy exemptions, documentation, assignment customization.
- Non-compliance reporting and remediation task management.

## Recommendation for existing deployment using EPAC

If you already use the `Sync-ALZPolicies` command you should move to the new process as the assignments are no longer being maintained. Follow the instructions below to create a policy structure file and then perform a sync. The main difference existing users will notice is there is that all the assignments have been split out into single files instead of the existing structure. For ease of use these are now grouped into folders based on landing zone archetypes.

## Scenarios

1. Existing Azure Landing Zones deployment and EPAC is to be used as the policy engine moving forward.
2. Using EPAC to deploy and manage the Azure Landing Zone policies.

In both cases it is now recommended that if you have the default ALZ policies deployed you should use the new method to provide a consistent sync process.

## Using the new Azure Landing Zone Library sync process

### Create a policy default structure file

This file contains information that drives the sync process. The file includes management group IDs, default enforcement mode, and parameter values. It must be generated at least once before executing the sync process.

1. Ensure that the EPAC module is up to date.
2. Follow the example below to clone the library repository and create the default file. There are examples below on how to run this commnand.

```ps1
# Create a default file for ALZ policies using the latest version of the ALZ Library 
New-ALZPolicyDefaultStructure -Type ALZ

# Create a default file for ALZ policies specifiying a tagged version of the ALZ Library 
New-ALZPolicyDefaultStructure -Type ALZ -Tag "platform/alz/2025.02.0"

# Create a default file for ALZ policies by provising a path to a cloned/modified library 
New-ALZPolicyDefaultStructure -Type ALZ -LibraryPath <<path to library>>

# Create a default file for AMBA policies using the latest version of the ALZ Library 
New-ALZPolicyDefaultStructure -Type AMBA
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

The next command will generate policy assignments based on the values in this file so ensure they are correct for your environment.

4. Follow the example below to sync the policy files and update scopes and parameters based on the information in the previously created file.

```ps1
# Sync the ALZ policies and assign to the "epac-dev" PAC environment.
Sync-ALZPolicyFromLibrary -Type ALZ -DefinitionsRootFolder .\Definitions -PacEnvironmentSelector "epac-dev"

# Sync the ALZ policies and assign to the "epac-dev" PAC environment. Specify a tagged version of the ALZ library
Sync-ALZPolicyFromLibrary -Type ALZ -DefinitionsRootFolder .\Definitions -PacEnvironmentSelector "epac-dev" -Tag "platform/alz/2025.02.0"

# Sync the ALZ policies from a cloned/modified library
Sync-ALZPolicyFromLibrary -Type ALZ -DefinitionsRootFolder .\Definitions -PacEnvironmentSelector "epac-dev" -LibraryPath <<path to library>>

# Sync the AMBA policies and assign to the "epac-dev" PAC environment.
Sync-ALZPolicyFromLibrary -Type AMBA -DefinitionsRootFolder .\Definitions -PacEnvironmentSelector "epac-dev"
```

Carefully review the generated policy assigments and ensure all parameter and scope information is correct.

5. When complete run `Build-DeploymentPlans` to ensure the correct changes are made. During the first sync for either a new or existing environment there will be many changes due to updating of the existing policies.

## Advanced Scenarios

Using the format of the Azure Landing Zones repository it is possible to extend the management groups defined and provide your own archetypes. You must maintain a local copy of the library for this purpose. Details will be provided at a later stage on how to customize this.
