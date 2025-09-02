# Lighthouse Subscription Management with EPAC

## Overview

While EPAC is not currently able to handle all use cases for Lighthouse integration, there are two specific use cases requested through GitHub issues that have been accounted for. The following is offered as guidance around those use cases. It is possible that the work done to account for these use cases may allow for other, untested functionality; so trying different permutations of the below-mentioned pacSelector settings may result in additional, undocumented functionality.

## Use-case 1: Additional role assignment from managing tenant to managed subscriptions

There are instances where you may need to make additional role assignments to managed subscriptions while assigning policy at your managing tenant. The guidance below covers a specific use case and all EPAC configurations necessary to achieve it.

### Use-case

When assigning Deploy Diagnostic Settings type policies at a scope in your managing tenant, you want to write the diagnostics data to a managed (Lighthouse-joined) subscription.

### Configurations

1. pacSelector Configuration.

In your global settings file, find the specific pacEnvironments that will have diagnostic settings policy deployed to them, where the diagnostics data needs to be written to a Lighthouse-managed subscription. Add the following to that pacSelector in the global settings file:

                "managedTenant": {
                    "managedTenantId": "00000000-1111-2222-3333-444444444444",
                    "managedTenantScopes": [
                        "/subscriptions/00000000-1111-2222-3333-444444444444",
                        "/subscriptions/00000000-1111-2222-3333-444444444444"
                    ]
                },

- **managedTenantId** - The tenant containing the lighthouse managed (joined) subsciptions.
- **managedTenantScopes** - A list of all subscriptions that may need "remote" role assignments made to them.  These would be the subscriptions that contain, for example, the Log Analytics Workspace or Storage Account that your are writing diagnostics data to across tenants.  Every subscription where this pacEnvironment may need to make a role assignment to must be listed.

1. In the assignment file, add an additionalRoleAssignments section for the file or node so that the assignment knows that for assigning this policy, at this (managing) pacEnvironment, it needs to perform an additional role assignment at the remote (managed) scope. The scope of the assignment must be included in the managedTenantScopes for the pacEnvironment in the globalSettings file.

                "additionalRoleAssignments": {
                    "managingTenantScopeEnv": [
                        {
                            "roleDefinitionId": "/providers/microsoft.authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
                            "scope": "/subscriptions/00000000-1111-2222-3333-444444444444",
                            "crossTenant": true
                        }
                    ]
                },
        
## Use-case 2: Make Role Assignments at Lighthouse-Managed Scopes While Deploying to the Cast Instance of That Subscription in Your Tenant

This feature is primarily meant for MSPs managing customer subscriptions. While the complete implementation is not perfect, this is due to a deficiency in Lighthouse functionality. Guidance on the best way to work around that with EPAC is provided.

### Use-case

This feature allows users to assign policies with role assignments to managed subscriptions without direct access to the customer tenant.

### Configurations

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
            "managedSubscription": true,                                                       <----Indicates this is a managed subscription
            "managedIdentityLocation": "eastus2",
            "managedTenant": {
                "managedTenantId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",                     <----Customer tenant ID
                "managedTenantScopes": [
                    "/subscriptions/999999-8888-7777-6666-555555555555"                        <----Customer subscription
                ]
            },
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false
            },
            "deployedBy": "My Org Admins"                                                      <----Friendly name to indicate who is deploying policy
        },
```

> [!NOTE]
> Because Lighthouse does not allow grouping of "cast" Lighthouse subscriptions in the managing tenant, and does not allow for management groups to be cast, each unique subscription must be a unique pacEnvironment. The best way to perform mass deployments is through custom pipelines that create multiple plans with unique names and then run multiple deployments. It is recommended to use self-hosted agents in this scenario, as you can create larger SKU agents that allow for parallelism.