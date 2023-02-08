# Cloud Adoption Framework Policies

**On this page**

* [Rationale](#rationale)
* [Sync Script](#sync-script)
* [Update Assignment Scopes](#update-assignment-scopes)
* [Update Assignment Parameters](#update-assignment-parameters)
* [Reading List](#reading-list)

## Rationale

Microsoft publishes and maintains a [list of Policies, Policy Sets and Assignments](https://github.com/Azure/Enterprise-Scale/blob/main/docs/ESLZ-Policies.md) which are deployed as part of the Cloud Adoption Framework Azure Landing Zones deployment. The central repository that contains these policies acts as the source of truth for ALZ deployments via the portal, Bicep and Terraform. A current list of policies which are deployed using these solutions is found at this link.

To enable customers to use the Enterprise Policy as Code solution and combine Microsoft's policy recommendations there is a script which will pull the Policies, Policy Sets and Policy Assignments from the central repository and allow you to deploy them using this solution.

As the policies and assignments change in main repository the base files in this solution can be updated to match.

## Sync Script

The script located at ```Scripts\CloudAdoptionFramework\Sync-CAFPolicies.ps1``` will synchronise the policies from the upstream repository. You should ensure that you are keeping the main repository in sync with the project fork to ensure that any changes to this script are reflected accurately.

```ps1
.\Scripts\CloudAdoptionFramework\Sync-CAFPolicies.ps1 [[-DefinitionsRootFolder] <string>]
```

Specifying the ```DefinitionsRootFolder``` parameter allows to you sync the policies to a different folder. This may be preferable when running yhe script periodically to sync in changes.

## Update Assignment Scopes

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

## Update Assignment Parameters

Several of the assignment files also have parameters which need to be in place. Pay attention to the requirements about having a Log Analytics workspace deployed prior to assigning these policies as it is a requirement for several of the assignments. Less generic parameters are also available for modification in the assignment files.

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

**[Return to the main page](../README.md)**
