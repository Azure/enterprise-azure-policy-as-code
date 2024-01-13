# App Registrations Setup

CI/CD pipelines/workflows require the creation of App Registrations in your Entra ID (Azure AD) tenants. The App Registrations are used by the EPAC pipeline to deploy the EPAC Management Group and the EPAC Management Group Policy Definitions.

The following screenshot shows the Management Group hierarchy that used for the App Registrations.

![Management Group hierarchy](Images/ci-cd-mg.png)

## Custom `EPAC Resource Policy Reader Role`

EPAC uses a set of Entra ID App Registrations (Service Principals). To build the deployment plan and adhere to the least-privilege-principle, a Resource Policy Reader role is required. This role is not built-in. EPAC contains script `New-AzPolicyReaderRole.ps1` to create this role or you can use the below JSON in Azure Portal.

```json
{
    "properties": {
        "roleName": "EPAC Resource Policy Reader",
        "description": "Provides read access to all Policy resources for the purpose of planning the EPAC deployments.",
        "assignableScopes": [
            "/"
        ],
        "permissions": [
            {
                "actions": [
                    "Microsoft.Authorization/policyassignments/read",
                    "Microsoft.Authorization/policydefinitions/read",
                    "Microsoft.Authorization/policyexemptions/read",
                    "Microsoft.Authorization/policysetdefinitions/read",
                    "Microsoft.PolicyInsights/*",
                    "Microsoft.Management/register/action",
                    "Microsoft.Management/managementGroups/read"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
```

## Create single App Registration and Role assignments for `epac-dev`

Create the App Registrations for:

- epac-dev environment with Owner rights to the epac-dev Management Group
- Optional: epac-test environment with Owner rights to the epac-test Management Group (repeat the steps below for epac-test)

### Create the App Registration for `epac-dev` environment

![App Registration 1](Images/ci-cd-app-reg-perm-1.png)

### Grant the App Registration the necessary Microsoft Graph permissions

![App Registration 2](Images/ci-cd-app-reg-perm-2.png)

![App Registration 3](Images/ci-cd-app-reg-perm-3.png)

![App Registration 4](Images/ci-cd-app-reg-perm-4.png)

![App Registration 5](Images/ci-cd-app-reg-perm-5.png)

![App Registration 6](Images/ci-cd-app-reg-perm-6.png)

![App Registration 7](Images/ci-cd-app-reg-perm-7.png)

![App Registration 8](Images/ci-cd-app-reg-perm-8.png)

![App Registration 9](Images/ci-cd-app-reg-perm-9.png)

![App Registration 10](Images/ci-cd-app-reg-perm-a.png)

### Grant the App Registration the necessary Azure `Owner` permissions for the epac Management Group

![App Registration 11](Images/ci-cd-app-reg-perm-b.png)

![App Registration 12](Images/ci-cd-app-reg-perm-c.png)

![App Registration 13](Images/ci-cd-app-reg-perm-d1.png)

![App Registration 14](Images/ci-cd-app-reg-perm-d2.png)

![App Registration 15](Images/ci-cd-app-reg-perm-d3.png)

![App Registration 16](Images/ci-cd-app-reg-perm-d4.png)

![App Registration 17](Images/ci-cd-app-reg-perm-d5.png)

## Create App Registrations and Role assignments for prod environments (per tenant)

### App Registration  with permissions to read Policy resources and Azure roles

#### Create the App Registration the same as above with the same Microsoft Graph permissions

![App Registration](Images/ci-cd-app-reg-root-reader.png)

#### Create custom Azure role with permissions to read Policy resources

![Reader Role 18](Images/ci-cd-role-policy-reader-1.png)

![Reader Role 19](Images/ci-cd-role-policy-reader-2.png)

![Reader Role 20](Images/ci-cd-role-policy-reader-3.png)

![Reader Role 21](Images/ci-cd-role-policy-reader-4.png)

![Reader Role 22](Images/ci-cd-role-policy-reader-5.png)

#### Grant the App Registration the custom Azure role at the root Management Group

![App Registration 23](Images/ci-cd-app-reg-root-reader-perm-1.png)

![App Registration 24](Images/ci-cd-app-reg-root-reader-perm-2.png)

### App Registration with permissions to deploy Policy resources

### Create the App Registration ***without*** Microsoft Graph permissions

![App Registration 25](Images/ci-cd-app-reg-root-contributor.png)

#### Grant the App Registration the `ResourcePolicy Contributor` role at the root Management Group

![App Registration 26](Images/ci-cd-app-reg-root-contributor-perm-1.png)

![App Registration 27](Images/ci-cd-app-reg-root-contributor-perm-2.png)

### App Registration with permissions to assign Roles at root Management Group

#### Create the App Registration the same as above with the same Microsoft Graph permissions

![App Registration 28](Images/ci-cd-app-reg-root-roles.png)

#### Grant the App Registration the `User Access Administrator` role at the root Management Group

![App Registration 29](Images/ci-cd-app-reg-root-role-assignments-perm-1.png)

![App Registration 30](Images/ci-cd-app-reg-root-role-assignments-perm-2.png)
