# Breaking changes in v6.0

**On this page**

* [Changed az cli to Az PowerShell Modules](#changed-az-cli-to-az-powershell-modules)
* [Recommendation to Simplify GitHub Flow](#recommendation-to-simplify-github-flow)
* [Renamed `Definitions` Folders](#renamed-definitions-folders)
* [Replaced `-SuppressDelete` Switch with Desired State Handling](#replaced--suppressdelete-switch-with-desired-state-handling)
* [Replaced `-IncludeResourceGroups` Switch with Desired State Handling](#replaced--includeresourcegroups-switch-with-desired-state-handling)
* [Multiple Changes in `global-settings.jsonc`](#multiple-changes-in-global-settingsjsonc)
* [Centralized Documentation in Docs folder](#centralized-documentation-in-docs-folder)
* [Microsoft Breaking Change in Implementation of  `Get-AzRoleAssignment`](#microsoft-breaking-change-in-implementation-of--get-azroleassignment)
* [Reading List](#reading-list)

## Changed az cli to Az PowerShell Modules

To increase execution speed and pipeline uniformity:

* Replaced az cli usage with faster Resource Graph queries and AZ PowerShell Modules.
* Simplified the cmdlets naming.
* Simplified parameters
* Removed -SuppressDeletes flag
* Changed handling of plan files
* Support to write pipeline variables for GitLab

Change pipeline definition:

* Change usage of task: `AzureCLI@2` to task: `AzurePowerShell@5`. Use `-devOpsType "ado"` for Azure DevOps or `-devOpsType "gitlab"` for Gitlab pipelines.

``` yaml
    - task: AzurePowerShell@5
      name: planStep
      displayName: Plan
      inputs:
        azureSubscription: $(devServiceConnection)
        pwsh: true
        azurePowerShellVersion: LatestVersion
        ScriptPath: "Scripts/Deploy/Build-DeploymentPlans.ps1"
        ScriptArguments:
          -pacEnvironmentSelector $(pacEnvironmentSelector) `
          -devOpsType "ado" `
          -InformationAction Continue
```

* Changed command line arguments as needed
* Change command names in pipeline definition
  * `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` to `Build-DeploymentPlans.ps1`
  * `Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1` to `Deploy-PolicyPlan.ps1`
  * `Set-AzPolicyRolesFromPlan.ps1` to `Deploy-RolesPlan.ps1`
* Fix the artifact up/downloads occurrences by replacing the publish and artifact line items with:

``` yaml
    - publish: "$(PAC_OUTPUT_FOLDER)/plans-$(pacEnvironmentSelector)"
      artifact: "plans-$(pacEnvironmentSelector)"
      condition: and(succeeded(), or(eq(variables['planStep.deployPolicyChanges'], 'yes'), eq(variables['planStep.deployRoleChanges'], 'yes')))
```

## Recommendation to Simplify GitHub Flow

We have found that the additional test environment after a Pull Request merge does not lead to finding problems; therefore, we removed that stage from the starter kit pipelines as seen in our [CI/CD Pipeline documentation](ci-cd-pipeline.md#simplified-github-flow-for-policy-as-code).

## Renamed `Definitions` Folders

Renamed definition folders to match Microsoft's standard naming in our Policy repo on GitHub. Rename the folders in your repo to:

* policyDefinitions
* policySetDefinitions
* policyAssignments
* policyExemptions
* policyDocumentations

## Replaced `-SuppressDelete` Switch with Desired State Handling

As part of the support for [multiple EPAC (and other PaC) solutions to manage Policy in a tenant(s)](desired-state-strategy.md), we changed our approach to "brownfield" scenarios. The setting has moved to `global-settings.jsonc`.

Remove the command line switch `-SuppressDelete` in the pipeline and the `brownfield` variable. The equivalent in `global-settings.jsonc` is:

``` json
"desiredState":
{
  "strategy": "ownedOnly"
}
```

## Replaced `-IncludeResourceGroups` Switch with Desired State Handling

As part of the support for [multiple EPAC (and other PaC) solutions to manage Policy in a tenant(s)](desired-state-strategy.md), we changed our approach to including resource groups in desired state. Without any modifications, Resource Group level assignments are not managed by EPAC to preserve previous behavior.

Remove the command line switch `-IncludeResourceGroups` in the pipeline. The equivalent in `global-settings.jsonc` is:

``` json
"desiredState": {
    "includeResourceGroups": true,
}
```

## Multiple Changes in `global-settings.jsonc`

* Simplify and clarify `"rootScope"` definition by replaceing `"rootScope": { "ManagementGroupName": "my-mg"}` with `"deploymentRootScope": "/providers/Microsoft.Management/managementGroups/my-mg"`.
* Removed requirement to have a default subscription. Remove `"defaultSubscriptionId"` element from `global-settings.jsonc`.
* Support for multiple EPAC (and other PaC) solutions to manage Policy. Add required `"pacOwnerId": "e6581a31-51a3-4dc6-806d-2541dc251d31"`.
* Add element for [desired state handling](desired-state-strategy.md) as needed.

## Centralized Documentation in Docs folder

Instead of README.md files in multiple folders, move all content from `README.md` files not at the solution root to the `Docs` folder.

Remove `README.md` files in folders (and subfolders) `Pipeline`, `Definitions`, and `Scripts`.

## Microsoft Breaking Change in Implementation of  `Get-AzRoleAssignment`

The implementation was changed from Azure AD to MS Graph API impacting the roles requirements for the cmdlet. This changed the implementation of `New-AzPolicyReaderRole.ps1`. Add required `MS Graph` [permissions for the pipeline service connections](ci-cd-pipeline.md#ms-graph-permissions).

## Reading List

* [Setup DevOps Environment](operating-environment.md) .
* [Create a source repository and import the source code](clone-github.md) from this repository.
* [Select the desired state strategy](desired-state-strategy.md)
* Copy starter kit pipeline definition.
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.
* Optional: generate a starting point for the `Definitions` folders:
  * [Extract existing Policy resources from an environment](extract-existing-policy-resources.md).
  * [Import Policies from the Cloud Adoption Framework](cloud-adoption-framework.md).
  * Copy the sample Policy resource definitions in the starter kit to your `Definitions` folders.
* [Add custom Policies](policy-definitions.md).
* [Add custom Policy Sets](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).
* Import Policies from the [Cloud Adoption Framework](cloud-adoption-framework.md).
* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).

**[Return to the main page](../README.md)**
