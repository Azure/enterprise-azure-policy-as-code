# Integrating EPAC with Azure Landing Zones

## Rationale

Microsoft publishes and maintains a [list of Policies, Policy Sets and Assignments](https://aka.ms/alz/policies) which are deployed as part of the Cloud Adoption Framework Azure Landing Zones deployment. The central repository that contains these policies acts as the source of truth for ALZ deployments via the portal, Bicep and Terraform. A current list of policies which are deployed using these solutions is found at this link.

To enable customers to use the Enterprise Policy as Code solution and combine Microsoft's policy recommendations there is a script which will pull the Policies, Policy Sets and Policy Assignments from the central repository and allow you to deploy them using this solution.

As the policies and assignments change in main repository the base files in this solution can be updated to match.

## Why and when should you use EPAC to manage ALZ deployed policies

EPAC can be used to manage Azure Policy deployed using ALZ Bicep or Terraform using the scenarios below. Some reasons you may want to switch to EPAC policy management include:

- You have existing unmanaged policies in a brownfield environment that you want to deploy in the new ALZ environment. [Export the existing policies](start-extracting-policy-resources.md) and manage them with EPAC alongside the ALZ policy objects.
- You have ALZ deployed in a non standard way e.g. multiple management group structures for testing, non-conventional management group structure. The default assignment structure provided by other ALZ deployment methods may not fit your strategy.
- A team that is not responsible for infrastructure deployment e.g. a security team may want to deploy and manage policies.
- You require features from policy not available in the ALZ deployments e.g. policy exemptions, documentation, assignment customization.
- Non-compliance reporting and remediation task management.

Instructions are provided below for integrating with Bicep and Terraform deployments.

## Scenarios

There are two scenarios for integrating EPAC with ALZ.

1. Existing Azure Landing Zone deployment and EPAC is to be used as the policy engine moving forward.
2. Using EPAC to deploy and manage the Azure Landing Zone policies.

## Scenario 1 - Existing Deployment

With an existing Azure Landing Zone deployment you can use EPAC's extract scripts to extract the existing policies and assignments.

1. Install the EnterprisePolicyAsCode module from the PowerShell gallery and import it.

    ```ps1
    Install-Module EnterprisePolicyAsCode
    Import-Module EnterprisePolicyAsCode
    ```

2. Create a new policy definition folder structure using the command below.

    ```ps1
    New-HydrationDefinitionFolder -DefinitionsRootFolder .\Definitions
    ```

3. Update the `global-settings.json` file in the Definitions folder as described [here](settings-global-setting-file.md)

4. Extract the existing policies from the environment by using the extract functionality as described [here](start-extracting-policy-resources.md)

    This will create in the `Output` folder a group of folders containing the extracted policies. Note that it extracts all policies in the environment including ones not deployed by any of the Azure Landing Zone deployments.

5. Copy each of the folders in the `Output\Definitions` folder to the `Definitions` folder you created above.

6. At this point you can run the build script and generate a plan to validate what is going to be changed in the existing environment.

    ```ps1
    Build-DeploymentPlans -DefinitionsRootFolder Definitions -OutputFolder Output
    ```

    In a newly deployed CAF environment with no other policies the results of the plan should be similar to below - EPAC will update each policy definition, set definition and assignment with a [pacOwnerId](settings-global-setting-file.md#uniquely-identify-deployments-with-pacownerid)

    ```
    ===================================================================================================
    Summary
    ===================================================================================================
    Policy counts:
        0 unchanged
        116 changes:
            new     = 0
            update  = 116
            replace = 0
            delete  = 0
    Policy Set counts:
        0 unchanged
        7 changes:
            new     = 0
            update  = 7
            replace = 0
            delete  = 0
    Policy Assignment counts:
        0 unchanged
        30 changes:
            new     = 0
            update  = 30
            replace = 0
            delete  = 0
    Role Assignment counts:
        0 changes
    ```

7. Run the generated plan to deploy the policy objects

    ```ps1
    Deploy-PolicyPlan -DefinitionsRootFolder .\Definitions -InputFolder .\Output
    ```

8. Run the generated plan to update the role assignment objects

    ```ps1
    Deploy-RolesPlan -DefinitionsRootFolder .\Definitions -InputFolder .\Output
    ```

If you have deployed the Azure Landing Zone accelerator using Bicep or Terraform - they support incremental updates as new features are released. If you are going to use EPAC to manage policies in the environment then follow the steps below depending on which tool you have used to do the landing zone deployment.

### Bicep

- Do not deploy the policy modules when upgrading the Azure Landing Zones. Use the process [below](integrating-with-alz.md#keeping-up-to-date-with-changes-manually) to keep in sync with changes to ALZ policies.

### Terraform

- You must override the built-in management group archetypes to tell the Terraform module not to deploy policies. Sample files to replace the built-in archetypes are available in a repository [here](https://github.com/anwather/epac-removetf)

## Scenario 2 - ALZ Policy Deployment with EPAC

To deploy the ALZ policies using EPAC follow the steps below.

1. Install the EnterprisePolicyAsCode module from the PowerShell gallery and import it.

    ```ps1
    Install-Module EnterprisePolicyAsCode
    Import-Module EnterprisePolicyAsCode
    ```

2. Create a new policy definition folder structure using the command below.

    ```ps1
    New-HydrationDefinitionFolder -DefinitionsRootFolder .\Definitions
    ```

3. Update the `global-settings.json` file in the Definitions folder as described [here](settings-global-setting-file.md)

4. Synchronize the policies from the upstream repository. You should ensure that you are running the latest version of the EPAC module before running this script each time.

    ```ps1
    Sync-ALZPolicies -DefinitionsRootFolder .\Definitions -CloudEnvironment AzureCloud
    # Also accepts AzureUSGovernment or AzureChinaCloud
    ```

5. Update the assignments scopes. Each assignment file has a default scope assigned to it - this need to be updated to reflect your environment and `global-settings.jsonc` file.

    For example:

    ```json
    {
        "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json",
        "nodeName": "/Root/",
        "scope": {
            "tenant1": [ // Replace with your EPAC environment name and validate the management group listed below exists
                "/providers/Microsoft.Management/managementGroups/toplevelmanagementgroup"
            ]
        },
        "parameters": {
            "logAnalytics": "", // Replace with your central Log Analytics workspace ID
            "logAnalytics_1": "", // Replace with your central Log Analytics workspace ID
            "emailSecurityContact": "", // Security contact email address for Microsoft Defender for Cloud
            "ascExportResourceGroupName": "mdfc-export", // Resource group to export Microsoft Defender for Cloud data to
            "ascExportResourceGroupLocation": "" // Location of the resource group to export Microsoft Defender for Cloud data to
    }
    ```

    If my top level management group had an ID of contoso and my PAC environments specified a production environment I would need to update the block as below.

    ```json
    {
        "nodeName": "/Root/",
        "scope": {
            "production": [
                "/providers/Microsoft.Management/managementGroups/contoso"
            ]
        },
        "parameters": {
            "logAnalytics": "",
            "logAnalytics_1": "",
            "emailSecurityContact": "",
            "ascExportResourceGroupName": "",
            "ascExportResourceGroupLocation": ""
        }
    ```

    Each assignment file corresponds to a management group deployed as part of the [CAF Azure Landing Zone](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-management-groups#management-groups-in-the-azure-landing-zone-accelerator) management group structure.

6. Update assignment parameters.

> [!WARNING]
> Carefully review the parameters and policies deployed as they have recently changed. Review each assignment file carefully and ensure all parameter values are completed. Due to changes in usage of the Azure Monitor Agent - there are some Data Collection Rules that must be deployed prior to assigning the policies - the source for these DCRs are provided in the assignment file parameter comments.

    Several of the assignment files also have parameters which need to be in place. Pay attention to the requirements about having a Log Analytics workspace deployed prior to assigning these policies as it is a requirement for several of the assignments. Less generic parameters are also available for modification in the assignment files.

7. Follow the normal steps to deploy the solution to the environment.

## Keeping up to date with changes manually

The Azure Landing Zone deployment contains several policies that help provide guardrails to an environment, and the team that works on these policies is always providing updates to the original content to keep in line with Microsoft's best practices and road maps. The EPAC solution contains a function to help synchronize changes from the upstream project.

To pull the latest changes from the upstream repository - use the code below.

```ps1
Sync-ALZPolicies -DefinitionsRootFolder .\Definitions -CloudEnvironment AzureCloud # Also accepts AzureUSGovernment or AzureChinaCloud
```

Carefully review the proposed changes before deploying them. It is best to make sure you're project is stored in source control so you can easily see which files have changed before deployment.

> [!WARNING]
> If you have followed Scenario 1 above, the first time you run the `Sync-ALZPolicies`, there will be many changes recorded due to formatting. Review the files completely before deploying.

> [!WARNING]
> Assignments deployed via the ALZ accelerators are kept in sync with the EnterprisePolicyAsCode module so ensure you have the latest PowerShell module installed before running `Sync-ALZPolicies`

> [!TIP]
> Rename or copy the default ALZ assignment files - when you do a sync, it makes it easier to compare changes.

## Keeping up to date with GitHub Actions

There is a GitHub action workflow which executes the above script. The process for configuring it is below.

1. Copy the `alz-sync.yaml` file from [here](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/StarterKit/Pipelines/GitHubActions/alz-sync.yaml) to `.github\workflows\alz-sync.yaml` in your repository.
2. Update the `env:` section with details below

    | Environment Variable Name | Value | Notes |
    |---|---|---|
    | REVIEWER | Add a GitHub user to review the PR |
    | definitionsRootFolder | The folder containing `global-settings.jsonc` and definitions |

3. Run the workflow - new policies will be synced from the source.
4. Before merging the PR - checkout the branch and confirm that changes. Note that the sync script will overwrite the default assignments so ensure you compare for new functionality before reverting.
5. When changes are confirmed - merge the PR.
