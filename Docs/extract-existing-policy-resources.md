# Extract existing Policy Resources from an Environment

**On this page**

* [\[Preview\] Script `Build-DefinitionsFolder`](#preview-script-build-definitionsfolder)
* [Preview Caveats](#preview-caveats)
* [Reading List](#reading-list)

## [Preview] Script `Build-DefinitionsFolder`

> ---
> ---
>
> **WARNING:** <br/>
> This is a preview version which [may produce strange assignment files](#preview-caveats) in rare circumstances. If you see such a problem, please [raise a GitHub issue](https://github.com/Azure/enterprise-azure-policy-as-code/issues/new).
>
> ---
> ---

<br/>

Extracts existing Policies, Policy Sets, and Policy Assignments and outputs them in EPAC format into subfolders in folder (`$outputFolders/Definitions`). The subfolders are `policyDefinitions`, `policySetDefinitions`, and `policyAssignments`. In a new EPAC instance these subfolders can be directly copied to the`Definitions` folder enabling an initial transition from a pre-EPAC to EPAC environment.

> ---
> ---
>
> **WARNING:** <br/>
> The script deletes the `$outputFolders/Definitions` folder before creating a new set of files. In interactive mode it will ask for confirmation before deleting the directory.
>
> ---
> ---

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Optional | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `definitionsRootFolder` | Optional | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `outputFolder` | Optional | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.
| `interactive` | Optional | Script is being run interactively and can request az login. It will also prompt for each file to process or skip. Defaults to $true. |
| `includeChildScopes` | Optional | Switch parameter to include Policies and Policy Sets in child scopes; child scopes are normally ignored for definitions. This does not impact Policy Assignments. |

<br/>

The scripts creates a `Definitions` folder in the `outputFolder` and subfolders for `policyDefinitions`, `policySetDefinitions` and `policyAssignments`. To use the genaerated files copy them to your `Definitions` folder.

* `policyDefinitions`, `policySetDefinitions` have a subfolder based on `metadata.category`. If the definition has no `category` `metadata` they are put ina subfolder labeled `Unknown Category`. Duplicates when including child scopes are sorted into the `Duplicates` folder. Creates one file per Policy and Policy Set.
* `policyAssignments` have a subfolder `policy` for assignments of a single Policy, or a subfolder `policySet` for assignment of a Policy Set. Creates one file per unique assigned Policy or Policy Set spanning multiple Assignments.

## Preview Caveats

The extraction are subject to the following assumptions and caveats:

* Names of Policies and Policy Sets are unique across multiple scopes (switch `includeChildScopes` is used)
* Assignment names are the same if the parameters match across multiple assignments across scopes for the same `policyDefinitionId` to enable optimization of the JSON.
* Ignores Assignments auto-assigned by Security Center (Defender for Cloud) at subscription level.
* Does not collate across multiple tenants.
* Does not calculate any `additionalRoleAssignments`.
* Only optimizes the tree structure from the three levels in the following order:
  * `policyDefinition` (name or id)
  * `parameters` per parameter set for the `policyDefinition`
  * Assignment name, **scopes**, and other attributes
* In some cases, ordering scope would yield a more compact tree structure:
  * `policyDefinition` (name or id)
  * Assignment name, **scopes**, and other attributes
  * `parameters` per parameter set for the `policyDefinition`
* Doesn't (yet) collate multiple assignments in support of CSV files for parameters. Use `Build-PolicyDocumentation.ps1` to generate CSV files and edit the corresponding assignments to reference the CSV file
* Doesn't generate Exemptions; use `Get-AzExemptions.ps1` instead.

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
