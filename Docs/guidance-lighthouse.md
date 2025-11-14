# Lighthouse Subscription Management with EPAC

## Overview

EPAC is able to handle most use cases as it pertains to Azure Lighthouse.  Specifically the complexities of cross-tenant role assignments.  Below is an example use case outlining how to configure the ability to to make an additional role assignment at a scope in a managing tenant when deploying a policy to your managed subscription through EPAC

## Use-case 1: Additional role assignment from managed subscriptions to managing tenant

There are instances where you may need to make additional role assignments to your managing tenant while assigning policy at your managed subscription. The guidance below covers a specific use case and all EPAC configurations necessary to achieve it.

### Use-case

When assigning Deploy Diagnostic Settings type policies at a scope in your managed subscription using EPAC, you want to write the diagnostics data to a log analytics workspace in your managing tenant.

### Configurations

1. pacSelector Configuration.

In your global settings file, update the lighthouse pacSelector to have the managingTenantID.  This lets EPAC know that this is a lighthouse "cast" tenant.

                "pacSelector": "epac-Managed",
                "cloud": "AzureCloud",
                "tenantId": "b729f34b-bc9a-4e55-b94e-63c03c65d113",
                "deploymentRootScope": "/subscriptions/6c0b3a4a-4c56-4866-8083-bb72aa71f174",
                "managedTenantId": "b617e3d0-18db-4bb6-afa1-662c906c2549",
                "managedIdentityLocation": "eastus2",

- **managedTenantId** - The tenant containing the lighthouse managed (joined) subsciptions.

1. In the assignment file, add an additionalRoleAssignments section for the file or node so that the assignment knows that when assigning this policy at the managed scope pacEnvironment, it needs to perform an additional role assignment at the managing scope. 

                "additionalRoleAssignments": {
                    "managingTenantScopeEnv": [
                        {
                            "roleDefinitionId": "/providers/microsoft.authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
                            "scope": "/subscriptions/00000000-1111-2222-3333-444444444444",
                        }
                    ]
                },

**Lighthouse Setup**

Before any EPAC functionality can work, you must first provide the service principal executing EPAC (in the managing tenant) the appropriate access in the managed (Lighthouse-invited) subscriptions. There are two components to this. Because you can configure EPAC to run plans, policy deployments, and role deployments with different service principals—or use the same service principal for all three actions—the guidance here assumes a singular service principal. If you are using a different service principal for each stage, adjust the Lighthouse template accordingly. 

1. **Determine Required Roles for Basic EPAC Functionality**
   - The combined required roles are:
        - Reader
        - Resource Policy Contributor
        - User Access Administrator.

1. **Determine Roles Needed for Policy Assignments (DINE/Modify)**
    - This is likely a dynamic list and will change over time.  Be as proactive and forward thinking as you can in developing this list as any changes to this list will require a re-invite for each lighthouse subscription.

1. **Create Your Lighthouse Invite Template**

    1. Open Lighthouse in your managing tenant
    1. Click "Manage your Customers"
    1. Click "Create ARM Template"
    1. Give the offer a name and description.
    1. Choose the scopt your will request to manage
    1. Click "+ Add authorization"
        1. Choose "Principal type" (Service Principal for EPAC)
        1. Select your principal
        1. Add Display name
        1. Select your role (from the list developed in item 1 above e.g. Reader, Resource Policy Contributor, and User Access Administrator)
        1. Add authorization for all roles that need to be assigned to your principal
        1. Click "View template"
        1. Download the template and open it to edit
        1. In the "authorizations" section, find all instances where you are assigning the User Access Administrator (18d7d88d-d35e-4fb5-a5c3-7773c20a72d9)
        1. Add the roles determined above in item 2 in a "delegatedRoleDefinitionIds" array, the delegated roles that your User Access Administrator will be able to add and remove.

        Example:

```json
        "delegatedRoleDefinitionIds": [
            "b24988ac-6180-42a0-ab88-20f7382dd24c",   <----Contributor
            "f353d9bd-d4a6-484e-a77a-8050b599b867",   <----Automation Contributor
            "91c1777a-f3dc-4fae-b103-61d183457e46"    <----Managed Services Registration assignment Delete Role
        ]
```

Once completed, send this file to your customer to be executed in each of their subscriptions where you will need to manage policies. It will take between 30 seconds and 30 minutes for the registration to complete (usually closer to 30 seconds). To view your customers, go to Lighthouse in your tenant and view customers. If you are not seeing all of them, you may need to change your global filters.

**EPAC Setup for Each Target Subscription**

After the Lighthouse portion is complete you will need to set things up in EPAC for each target subscription.  Below is an example with explanation of the relevant properties.

```json
        {
            "pacSelector": "epac-ManagedCustomerSubscription1",
            "cloud": "AzureCloud",
            "tenantId": "00000000-1111-2222-3333-444444444444",                                <----My Tenant
            "deploymentRootScope": "/subscriptions/999999-8888-7777-6666-555555555555",        <----Customer subscription
            "managedTenantId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",                         <----Customer tenant ID
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false
            },
            "deployedBy": "My Org Admins"
        },
```

> [!NOTE]
> Because Lighthouse does not allow grouping of "cast" Lighthouse subscriptions in the managing tenant, and does not allow for management groups to be cast, each unique subscription must be a unique pacEnvironment. The best way to perform mass deployments is through custom pipelines that create multiple plans with unique names and then run multiple deployments. It is recommended to use self-hosted agents in this scenario, as you can create larger SKU agents that allow for parallelism.