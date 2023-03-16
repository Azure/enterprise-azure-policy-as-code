# Integrating EPAC with Azure Landing Zones

## Rationale

Microsoft publishes and maintains a [list of Policies, Policy Sets and Assignments](https://github.com/Azure/Enterprise-Scale/blob/main/docs/ESLZ-Policies.md) which are deployed as part of the Cloud Adoption Framework Azure Landing Zones deployment. The central repository that contains these policies acts as the source of truth for ALZ deployments via the portal, Bicep and Terraform. A current list of policies which are deployed using these solutions is found at this link.

To enable customers to use the Enterprise Policy as Code solution and combine Microsoft's policy recommendations there is a script which will pull the Policies, Policy Sets and Policy Assignments from the central repository and allow you to deploy them using this solution.

As the policies and assignments change in main repository the base files in this solution can be updated to match.

## Scenarios

There are two scenarios for integrating EPAC with ALZ.

1) Existing Azure Landing Zone deployment and EPAC is to be used as the policy engine moving forward
2) Using EPAC to deploy and manage the Azure Landing Zone policies

## 1 - Existing Deployment

## 2 - ALZ Policy Deployment with EPAC

To deploy the ALZ policies using EPAC follow the steps below.

1) Install the EnterprisePolicyAsCode module from the PowerShell gallery and import it.

```
Install-Module EnterprisePolicyAsCode
Import-Module EnterprisePolicyAsCode
```
2) Create a new policy definition folder structure using the command below.

```
New-EPACDefinitionFolder -DefinitionsRootFolder .\Definitions
```
3) Update the ```global-settings.json``` file in the Definitions folder as described [here](definitions-and-global-settings.md#global-settings)

4) Synchronise the policies from the upstream repository. You should ensure that you are running the latest version of the EPAC module before running this script each time. 

```
Sync-CAFPolicies -DefinitionsRootFolder .\Definitions
```

5) Update the assignments scopes
Each assignment file has a default scope assigned to it - this need to be updated to reflect your environment and ```global-settings.jsonc``` file.

For example:

```json
{
    "nodeName": "/Root/",
    "scope": {
        "tenant1": [
            "/providers/Microsoft.Management/managementGroups/toplevelmanagementgroup"
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

If my top level management group had an ID of contoso I and my PAC environments specified a production environment I would need to update the block as below.

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

6) Update assignment parameters

Several of the assignment files also have parameters which need to be in place. Pay attention to the requirements about having a Log Analytics workspace deployed prior to assigning these policies as it is a requirement for several of the assignments. Less generic parameters are also available for modification in the assignment files.

7) Follow the normal steps to deploy the solution to the environment.

## Reading List

* [Setup DevOps Environment](operating-environment.md) .
* [Create a source repository and import the source code](clone-github.md) from this repository.
* [Select the desired state strategy](desired-state-strategy.md)
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.
* Optional: generate a starting point for the `Definitions` folders:
  * [Extract existing Policy resources from an environment](extract-existing-policy-resources.md).
  * [Import Policies from the Cloud Adoption Framework](cloud-adoption-framework.md).
* [Add custom Policies](policy-definitions.md).
* [Add custom Policy Sets](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).
* Import Policies from the [Cloud Adoption Framework](cloud-adoption-framework.md).
* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](operational-scripts.md).