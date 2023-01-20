
# Policy Assignments

**On this page**

* [Components](#components)
* [Assignment structure](#assignment-structure)
* [Assignment nodes](#assignment-nodes)
* [Details for `scope` and `notScope`](#details-for-scope-and-notscope)
  * [Using the `PacAssignmentSelector`](#using-the-pacassignmentselector)
  * [Resource Group patterns in `notScope`](#resource-group-patterns-in-notscope)
  * [Example Scope Definition](#example-scope-definition)
* [Define Assignment parameters with a CSV file](#define-assignment-parameters-with-a-csv-file)
* [Examples in StarterKit folder](#examples-in-starterkit-folder)
  * [Single node to assign allowed locations enforcement](#single-node-to-assign-allowed-locations-enforcement)
  * [Hierarchy to assign security and compliance initiatives](#hierarchy-to-assign-security-and-compliance-initiatives)
  * [Hierarchy to manage Azure resource tags](#hierarchy-to-manage-azure-resource-tags)
* [Reading List](#reading-list)

## Components

This chapter describes how **Policy Assignments** are handled by EPAC. To learn about how custom Policy and Initiative definitions are managed, see the [Policy Definitions](../Policies/README.md) and [Initiative Definitions](../Initiatives/README.md).

The components required for **creating / updating / deleting Policy assignments and Policy set (initiative) assignments** are the following:

| Component | What is it used for? | Where can it be found? |
|--|--|--|
| **Global Settings File** | The `global-settings.jsonc` file specifies common values for Policy Assignments. | `Definitions` folder |
| **Assignment JSON files** | The assignments JSON file follows the management group hierarchy (optionally including subscriptions and resource groups) and defines all policy and initiative assignments on these scopes. | `Definitions/policyAssignments` folder |
| **Parameters CSV files** (optional)| CSV files are referenced by the JSON files to simplify assignment parameter setting for large complex security and compliance focused Initiatives ([see details below](#define-assignment-parameters-with-a-csv-file)). | `Definitions/policyAssignments` folder |

## Assignment structure

Assignment JSON is hierarchical for efficient definitions, avoiding duplication of JSON with copy/paste. Each branch is cumulative, meaning:

* String values, such as names, descriptions are concatenated
* notScopes are stacked (union)
* parameters are stacked (union)
* Definitions of the Policy or Policy Set being assigned must exist exactly once in each branch
* Assignment scope(s) must exist exactly once in each branch
* parameterFile and parameterSelector for the **new** feature using a CSV spreadsheet to define effect parameters must exist exactly ones in each branch

For more details about the rules for every element supported, see the details in [Assignment nodes below](#assignment-nodes).

**Note:** the tree is not required to be balanced. The number of levels is not restricted; however, anything beyond 3 levels is unnecessary in real scenarios and would be difficult to read and manage.

![Assignment File Overview Diagram](Images/PaC-Assignment-Structure.png)

## Assignment nodes

| Key | Description | Rule |
|-----|-------------|------|
| `nodeName` | arbitrary name of the node for usage by the scripts to pinpoint format errors. | Must exist in each node. |
| `managedIdentityLocation` | Selects the Managed Identity location for Policies with `DeployIfnotExists` and `Modify` effects. | Any node: overrides previous setting. |
| `scope` | List of scopes for assignment. | Must exist exactly once in each branch of the tree. |
| `notScope` | List of notScopes. | Cumulative in branch. May not appear at a child node once the `scope` has been defined. |
| `assignment` | Assignment `name`, `displayName` and `description`. The fields `name` and `displayName` are required. | String values are concatenated in each branch. Assignment `name` lengths are limited to 24. Must exist at least once in every branch. |
| Option A: `parameters` | Parameter values for the assignment. Specified parameters not defined in the assigned Policy or Initiative are silently ignored. | Union of all the `parameters` defined in a branch. `parameters` redefined at a child (recursive) node overwrite the parent nodes value. |
| Option B: `parameterFile` and `parameterSelector` | [Efficiently specify the parameters for large Initiatives and lists of Initiative](#define-assignment-parameters-with-a-csv-file), across multiple target environment categories. | Must exist exactly once in each branch of the tree. |
| `ignoreBranch` | Ignore the rest of the tee staring at this node. Can be used to define future assignments without deploying the assignments. | Any node: overrides are ignored. |
| `enforcementMode` | Similar to `ignoreBranch`, it deploys the assignment and sets the assignment to `Default` or `DoNotEnforce`. `DoNotEnforce` allows a what if analysis. | Any node: overrides previous setting |
| `additionalRoleAssignments` | `roleDefinitionIds` are calculated from the included (direct or indirect via Initiative) Policy definition(s). Fo some Policies, such as DINE `diagnosticsSettings` the monitor destination might be in a different branch of the Management Group tree from the Assignment. This field specifies any roles requiring assignments in that MG branch. The value is an array, each element containing two items: `roleDefinitionId` and `scope` | Union of all the `additionalRoleAssignments` defined in this branch |
| Option 1: `definitionEntry` | Specify the `policyName` or `initiativeName` for the assignment. The name should not be a fully qualified `id`. `friendlyNameToDocumentIfGuid` is purely used as a comment to make the JSON more readable if the name is a GUID (optional). | Either option 1 or option 2 must exist exactly once in each branch of the tree. |
| Option 2: `definitionEntryList` | List of definitions to assign - creates one assignment per list entry for each tree branch. Each entry must specify a `policyName` or `initiativeName` and may specify `friendlyNameToDocumentIfGuid`. A nested `assignment` must be included to differentiate the multiple assignments being created from a `definitionEntryList`. This `assignment` structure may include an `append` boolean field to indicate that the fields should be appended instead of (default) concatenated first. | Either option 1 or option 2 must exist exactly once in each branch of the tree. |

## Details for `scope` and `notScope`

### Using the `PacAssignmentSelector`

The assignment selector determines the array being selected for this run of the script (e.g., `dev`, `test` and, `prod` above). Exact matches to the parameter `PacAssignmentSelector` for `Build-DeploymentPlans.ps1` select that array for `notScope` and `scope`. A star (`*`) in the assignment or globalSettings.jsonc file  always selects the array independent of the `PacAssignmentSelector`. The star is only useful in single tenant scenarios, except for Resource Group patterns.

### Resource Group patterns in `notScope`

`notScope` also accepts Resource Group name patterns with wild cards. Standard `notScope` definitions require fully qualified paths. This solution can add Resource Groups based on name patterns. The patterns are resolved during deployment. Any Resource Group added after the deployment are not automatically added. You must rerun the deployment pipeline to add new Resource Groups.

### Example Scope Definition

| Scope | Example |
|-------|---------|
| Management group | `/providers/Microsoft.Management/managementGroups/<managementGroupId>` |
| Subscription | `/subscriptions/<subscriptionId>` |
| Resource Group | `/subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>` |

## Define Assignment parameters with a CSV file

Assigning multiple security and compliance initiatives (e.g., Azure Security Benchmark, NIST 800-53 r5, PCI, NIST 800-171, ...) with just JSON becomes very complex fast. Assigning 5 such Initiatives to 4 environment categories, would require 21 nodes with may repeated items, causing the JSON file to ballon to thousands of lines.

Based on development of the documentation feature using spreadsheets as report output, that capability was adapted to use spreadsheets as input to control parameters for different parameters when deploying Assignments. This approach is best for very large Policy Sets such as Azure Security Benchmark, NIST 800-53, etc.

Start by generating documentation for one or more of those Policy Sets, then modify the effect and parameter columns for each type of environments you will use. In the assignment file, you specify `parameterFile` (must occur exactly once per tree branch) and which column prefix to use for a particular scope with `parameterSelector`.

If you are using multiple Policy Sets, than EPAC will:

* Use most restrictive effect for the first Policy Set
* Use Audit (if allowed for the second and subsequent Policy Sets)

## Examples in StarterKit folder

### Single node to assign allowed locations enforcement

Assignment file [allowed-locations-assignments.jsonc](../../StarterKit/Definitions/Assignments/allowed-locations-assignments.jsonc) contains a single node to assign a single Initiative to one scope.

### Hierarchy to assign security and compliance initiatives

Assignment file [security-baseline-assignments.jsonc](../../StarterKit/Definitions/Assignments/security-baseline-assignments.jsonc) contains 2 levels of hierarchy containing the root node and 2 child nodes. It uses a `definitionEntryList` instead of `definitionEntry`. Defining this with the `definitionEntry` approach would have increased the hierarchy from 2 levels (3 nodes) to 3 levels (7 nodes).

**Note**: With only two types of environments, 3 nodes versus 7 nodes is a small difference; however if you have a more complex environment differentiation with lots of environment types and parameters this becomes quickly untenable. As an extreme illustration with 8 environments (e.g., sandbox, dev, integration, testing, uat, perf, pre-prod and prod), you would need to specify 25 nodes. Such a file would likely be thousands of lines long and completely unreadable.

### Hierarchy to manage Azure resource tags

Assignment file [tag-assignments.jsonc](../../StarterKit/Definitions/Assignments/tag-assignments.jsonc) defines:

* Required tags and inherited tags with a `definitionEntryList` using 2 levels (plus the root node)
* Environment tag values for resource groups with a `definitionEntry` using two levels (plus the shared root node)

## Reading List

* [Setup DevOps Environment](operating-environment.md) .
* [Create a source repository and import the source code](clone-github.md) from this repository.
* [Select the desired state strategy](desired-state-strategy.md)
* [Copy starter kit pipeline definition and definition folder to your folders](starter-kits.md)
* [Define your deployment environment](definitions-and-global-settings.md) in `global-settings.jsonc`.
* [Build your CI/CD pipeline](ci-cd-pipeline.md) using a starter kit.
* [Add custom Policy definitions](policy-definitions.md).
* [Add custom Policy Set definitions](policy-set-definitions.md).
* [Create Policy Assignments](policy-assignments.md).
* Import Policies from the [Cloud Adoption Framework](cloud-adoption-framework.md).
* [Manage Policy Exemptions](policy-exemptions.md).
* [Document your deployments](documenting-assignments-and-policy-sets.md).
* [Execute operational tasks](operational-scripts.md).

**[Return to the main page](../README.md)**
