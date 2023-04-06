# Breaking changes

## Breaking changes in v7.0

Script `Export-AzPolicyResources` replaces `Build-PolicyDefinitionFolder` with a [substantial increase in capability](extract-existing-policy-resources.md). It has a round-trip capability supporting the extract to be used in the build `Definitions`.

Introducing a new approach using PowerShell Module. This not (actually) breaking existing implementation since you can continue as is; however, for a simplified usage of EPAC, the PowerShell module is the best approach.

The move from synchronizing your repo with the GitHub repo to a PowerShell module necessitated the reworking of the default values for `Definitions`, `Output`, and `Input` folders. Many scripts use parameters for definitions, input and output folders. They default to the current directory, which should be the root of the repo. make sure that the current directory is the root of your repo. We recommend that you do one of the following approaches instead of accepting the default:

- Set the environment variables `PAC_DEFINITIONS_FOLDER`, `PAC_OUTPUT_FOLDER`, and `PAC_INPUT_FOLDER`.
- Use the script parameters `-definitionsRootFolder`, `-outputFolder`, and `-inputFolder` (They vary by script).

## Breaking changes in v6.0

### Changed az cli to Az PowerShell Modules

To increase execution speed and pipeline uniformity:

- Replaced az cli usage with faster Resource Graph queries and AZ PowerShell Modules.
- Simplified the cmdlets naming.
- Simplified parameters
- Removed -SuppressDeletes flag
- Changed handling of plan files
- Support to write pipeline variables for GitLab

Change pipeline definition:

- Change usage of task: `AzureCLI@2` to task: `AzurePowerShell@5`. Use `-devOpsType "ado"` for Azure DevOps or `-devOpsType "gitlab"` for Gitlab pipelines.

```yaml
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

- Changed command line arguments as needed
- Change command names in pipeline definition
  - `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` to `Build-DeploymentPlans.ps1`
  - `Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1` to `Deploy-PolicyPlan.ps1`
  - `Set-AzPolicyRolesFromPlan.ps1` to `Deploy-RolesPlan.ps1`
- Fix the artifact up/downloads occurrences by replacing the publish and artifact line items with:

```yaml
    - publish: "$(PAC_OUTPUT_FOLDER)/plans-$(pacEnvironmentSelector)"
      artifact: "plans-$(pacEnvironmentSelector)"
      condition: and(succeeded(), or(eq(variables['planStep.deployPolicyChanges'], 'yes'), eq(variables['planStep.deployRoleChanges'], 'yes')))
```

### Recommendation to Simplify GitHub Flow

We have found that the additional test environment after a Pull Request merge does not lead to finding problems; therefore, we removed that stage from the starter kit pipelines as seen in our [CI/CD Pipeline documentation](ci-cd-pipeline.md#simplified-github-flow-for-policy-as-code).

### Renamed `Definitions` Folders

Renamed definition folders to match Microsoft's standard naming in our Policy repo on GitHub. Rename the folders in your repo to:

- policyDefinitions
- policySetDefinitions
- policyAssignments
- policyExemptions
- policyDocumentations

### Replaced `-SuppressDelete` Switch with Desired State Handling

As part of the support for [multiple EPAC (and other PaC) solutions to manage Policy in a tenant(s)](desired-state-strategy.md), we changed our approach to "brownfield" scenarios. The setting has moved to `global-settings.jsonc`.

Remove the command line switch `-SuppressDelete` in the pipeline and the `brownfield` variable. The equivalent in `global-settings.jsonc` is:

```json
"desiredState":
{
  "strategy": "ownedOnly"
}
```

### Replaced `-IncludeResourceGroups` Switch with Desired State Handling

As part of the support for [multiple EPAC (and other PaC) solutions to manage Policy in a tenant(s)](desired-state-strategy.md), we changed our approach to including resource groups in desired state. Without any modifications, Resource Group level assignments are not managed by EPAC to preserve previous behavior.

Remove the command line switch `-IncludeResourceGroups` in the pipeline. The equivalent in `global-settings.jsonc` is:

```json
"desiredState": {
    "includeResourceGroups": true,
}
```

### Multiple Changes in `global-settings.jsonc`

- Simplify and clarify `"rootScope"` definition by replaceing `"rootScope": { "ManagementGroupName": "my-mg"}` with `"deploymentRootScope": "/providers/Microsoft.Management/managementGroups/my-mg"`.
- Removed requirement to have a default subscription. Remove `"defaultSubscriptionId"` element from `global-settings.jsonc`.
- Support for multiple EPAC (and other PaC) solutions to manage Policy. Add required `"pacOwnerId": "e6581a31-51a3-4dc6-806d-2541dc251d31"`.
- Add element for [desired state handling](desired-state-strategy.md) as needed.

### Centralized Documentation in Docs folder

Instead of README.md files in multiple folders, move all content from `README.md` files not at the solution root to the `Docs` folder.

Remove `README.md` files in folders (and subfolders) `Pipeline`, `Definitions`, and `Scripts`.

### Microsoft Breaking Change in Implementation of  `Get-AzRoleAssignment`

The implementation was changed from Azure AD to MS Graph API impacting the roles requirements for the cmdlet. This changed the implementation of `New-AzPolicyReaderRole.ps1`. Add required `MS Graph` [permissions for the pipeline service connections](ci-cd-pipeline.md#ms-graph-permissions).
