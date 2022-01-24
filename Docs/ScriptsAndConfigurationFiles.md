## Policy and Initiative definition configuration scripts

The `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` analyzes changes in policy, initiative, and assignment files. The  `Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1` script is used to deploy policies, initiatives, and assignments at their desired scope, the `Remove-AzPoliciesIdentitiesRoles.ps1` file is used to remove unnecessary roles and identities given out previously, and the 'plan file.json' is an artifact created by the pipeline run that is used to show the expected changes in Azure.

![image.png](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/Images/FileProcessing.PNG)
The deployment scripts are **declarative** and **idempotent**: this means, that regardless how many times they are run, they always push all changes that were implemented in the JSON files to the Azure environment, i.e. if a JSON file is newly created/updated/deleted, the pipeline will create/update/delete the Policy and/or Initiative definition in Azure. If there are no changes, the pipeline can be run any number of times, as it won't make any changes to Azure.

## Global Settings Configuration File

The `global-settings.jsonc` file is located in the definitions folder and defines settings for all policy as code deployments with the following items:
- Managed Identity Locations
    + In this file, you must specify the locations for managed identities. This can be done for the entire platform by using the "*" operator or it can be specified on an environment level.
    + Typically this will be set to your primary tenant location
- Not scope
    + Not Scope is designed to act as a permanent exclusion from policy evaluation. As opposed to an exemption which has a set end date. This can also be set across the entire platform or at an environment level.
```json
{
    "managedIdentityLocation": {
        "*": "eastus2"
    },
    "notScope": {
        "*": [
            "/resourceGroupPatterns/DefaultResourceGroup*"
        ],
        "PAC-PROD": [
            "/providers/Microsoft.Management/managementGroups/ExcludedMG",
            "/providers/Microsoft.Management/managementGroups/AnotherExcludedMG"
        ]
    }
    /* "notScope" Instructions
        Formats of array entries:
            managementGroups:      "/providers/Microsoft.Management/managementGroups/myManagementGroupId"
            subscriptions:         "/subscriptions/00000000-0000-0000-000000000000"
            resourceGroups:        "/subscriptions/00000000-0000-0000-000000000000/resourceGroups/myResourceGroup"
            resourceGroupPatterns: No wild card or single * wild card at beginning or end of name or both; wild card in middle is invalid
                                   "/resourceGroupPatterns/name"
                                   "/resourceGroupPatterns/name*"
                                   "/resourceGroupPatterns/*name"
                                   "/resourceGroupPatterns/*name*"
    */
}
```
## Next steps
Read through the rest of the documentation and configure the pipeline to your needs.

- **[Definitions](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/Definitions.md)**
- **[Assignments](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/Assignments.md)**
- **[Pipeline](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/Pipeline.md)**
- **[Quick Start guide](https://github.com/Azure/enterprise-azure-policy-as-code#readme)**
- **[Operational Scripts](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/OperationalScripts.md)**

[Return to the main page.](https://github.com/Azure/enterprise-azure-policy-as-code)
