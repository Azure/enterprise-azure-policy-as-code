# Breaking changes in v6.0

## Why and what

We had make breaking changes to accommodate new features and improve speed. We decided to break all the items we had envisioned in one update.

| Reason | Change | Impact |
| :----- | :----- | :----- |
| Remove requirement to have a default subscription. | `"defaultSubscriptionId"` field removed from global-settings.jsonc | Modify global-settings.jsonc |
| Simplify and clarify `"rootScope"` definition. | Replace `"rootScope": { "ManagementGroupName": "my-mg"}` with `"deploymentRootScope": "/providers/Microsoft.Management/managementGroups/my-mg"` | Modify global-settings.jsonc |
| Support multiple EPAC (and other PaC) solutions to manage Policy. | Add `"pacOwnerId": "e6581a31-51a3-4dc6-806d-2541dc251d31"` | Modify global-settings.jsonc |
 Support "brownfield" scenarios with smarter more granular approach. | Remove the command line switch `-noDelete`. <br/><br/>Add (optional) element within each pacEnvironment `"desiredState": { "strategy": "ownedOnly" }`.  | Remove switch in CI/CD pipelines. <br/><br/>Modify global-settings.jsonc |
 | Simplify the command line and increase granularity for resource group handling. | Remove the command line switch `-includeResourceGroups`. <br/><br/>Add `"desiredState": { "includeResourceGroups": true }`.  | Remove switch in CI/CD pipelines. <br/><br/>Modify global-settings.jsonc |
 | Increase execution speed and pipeline uniformity. We replaced az cli usage with faster Resource Graph queries and AZ PowerShell Modules. Additionally we simplified the command lets naming. | Pipeline task use `task: AzurePowerShell@5`. <br/><br/>Modify script name and parameters. | Modify pipeline definition |
 | Rename definition folders to match Microsoft's standard naming in our Policy repo on GitHub. | Rename folders within `Definitions` folder (see below) | Change folder names |
 | Microsoft has deprecated Azure AD Graph API. It has been replaced with Microsoft Graph API impacting service connection setup | Add `MS Graph` [permissions](azure-devops-pipeline.md) for the pipeline service connections | Service Principal Permissions |
 | Centralized documentation files into Docs folder. | Readme.md files in `Definitions` folders are no longer used or updated, | Remove deprecated files from `Definitions` folders. They have been moved to the docs folder. | Remove the legacy `readme.md` files to avoid confusion.

## Upgrade path

For details consult the above table and the newly updated samples in StarterKit.

- Modify global-settings.jsonc (look at the example in the StarterKit)
  - pacOwnerId
  - Remove defaultSubscriptionId
  - Change rootScope to deploymentRootScope
  - If you used the switch parameters, add desiredState
    - strategy as ownedOnly
    - includeResourceGroups as true
- Rename the definition folders to
  - policyDefinitions
  - policySetDefinitions
  - policyAssignments
  - policyExemptions
  - policyDocumentations
- Remove `README.md` files from all Definitions folders.
- Fix the pipeline for
  - Changed command line arguments
  - Change command names
    - `Build-DeploymentPlans.ps1` to `Build-DeploymentPlans.ps1`
    - `Deploy-PolicyPlan.ps1` to `Deploy-PolicyPlan.ps1`
    - `Deploy-RolesPlan.ps1` to `Deploy-RolesPlan.ps1`
  - Change usage of `task: AzureCLI@2` to `task: AzurePowerShell@5`
  - Fix the artifact up/downloads.
  - If you're using Azure DevOps pipelines add parameter `-devOpsType "ado"` to `Build-DeploymentPlans.ps1`
- Add required `MS Graph` [permissions](azure-devops-pipeline.md) for the pipeline service connections.
