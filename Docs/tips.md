# Tips

Miscellaneous explanation to get the most from EPAC.

## Export-AzPolicyResources

If the `global-settings.jsonc` contains `managedIdentityLocations` or `globalNotScopes` any matching `managedIdentityLocations` and `notScopes` are not emitted as part of the assignment files.

## Parameter CSV Files

If an `effect` parameter is not specified in the CSV file, the default value from the definition is used.

If an `effect` for a Policy is not surfaced as a parameter at the Policy Set, EPAC will use the Policy Assignment `overrides` feature to set the desired value. Conversely, if an `effect` for a Policy is surfaced as a parameter at the Policy Set, EPAC will not use the Policy Assignment `overrides` feature to set the desired value.

Build-PolicyDocumentation.ps1 will include the `overrides` in the effective `effect` value.


## Role Assignments

`Build-DeploymentPlan.ps1` will not calculate Role Assignments for user-assigned Managed Identities (UAMI) and will not generate a `roles-plan.json` file.

`additionalRoleAssignments` are used when a resource required is not in the current scope. For example, a Policy Assignment that requires a Event Hub to be managed in a subscription not contained in the current management group.