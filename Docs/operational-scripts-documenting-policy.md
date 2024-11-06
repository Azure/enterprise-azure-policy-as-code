# Documenting Policy Assignments and Sets of Policy Set (Initiative) definitions

## Overview

The Documentation feature provides reports on Policy Assignments deployed within an environment, and comparisons of Policy Assignments and Sets of Policy Set definitions for considering differences in policies and effects.  Output is generated as Markdown (`.md`), and Excel (`.csv`) files using the script [`./Scripts/Operations/Build-PolicyDocumentation`](operational-scripts-reference.md#script-build-policydocumentation) It retrieves its instruction from the JSON files in this folder; the names of the definition JSON files don't matter as the script reads any file in the folder with a `.json` or `.jsonc` extension.

* Policy Assignments: Read and process Policy Assignments which are representative of an environment category, such as prod, test, dev, and sandbox. It generates Markdown (`.md`), and Excel (`.csv`) files.
* Policy Sets: Read and process Policy Sets to compare them for Policy and effect overlap. It generates Markdown (`.md`), Excel (`.csv`) files, and JSON file (`.jsonc`).

## JSON Schema

The GitHub repo contains a JSON schema which can be used in tools such as [VS Code](https://code.visualstudio.com/Docs/languages/json#_json-schemas-and-settings) to provide code completion.

To utilize the schema add a ```$schema``` tag to the JSON file.

```
{
  "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-documentation-schema.json"
}
```

This schema is new in v7.4.x and may not be complete. Please let us know if we missed anything.

## Example Documentation Specification File using 'documentAllAssignments'

Each file must contain one or both documentation topics. This example file in the StarterKit has both topics. The element `pacEnvironment` references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the custom Policies and Policy Sets are deployed.

* [`documentAssignments`](#assignment-documentation)
* [`documentPolicySets`](#policy-set-documentation)

```json
{
    "documentAssignments": {
        "documentAllAssignments": [
            {
                "pacEnvironment": "EPAC-Prod",
                "fileNameStemPrefix": "Production",
                "skipPolicyAssignments": [],
                "skipPolicyDefinitions": [
                    "/providers/microsoft.authorization/policysetdefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8" // Azure Security Benchmark v3
                ],
                "overrideEnvironmentCategory": {
                    "DEV": [ // Any name will suffice - will be header of column, grouping the scopes within the array
                        "/providers/Microsoft.Management/managementGroups/DEV-1",
                        "/providers/Microsoft.Management/managementGroups/DEV-2"
                    ],
                    "PROD": [
                        "/providers/Microsoft.Management/managementGroups/PROD-1",
                        "/providers/Microsoft.Management/managementGroups/PROD-2"
                    ]
                }
            }
        ],
        "documentationSpecifications": [
            {
                "fileNameStem": "contoso-policy-effects-across-environments",
                "environmentCategories": [], // when using 'documentAllAssignments', this value will be overwritten
                "title": "Contoso Policy effects",
                "markdownAdoWiki": true,
                "markdownIncludeComplianceGroupNames": true,
                "markdownSuppressParameterSection": false,
                "markdownMaxParameterLength": 42, //default is 42
                "markdownAdoWikiConfig": [
                    {
                        "adoOrganization": "MyOrganization",
                        "adoProject": "EPAC",
                        "adoWiki": "EPAC"
                    }
                ]
            }
        ]
    },
    "documentPolicySets": [
        {
            "pacEnvironment": "tenant",
            "fileNameStem": "contoso-compliance-policy-sets",
            "title": "Document interesting Policy Sets",
            "policySets": [
                {
                    "shortName": "ASB",
                    "id": "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8" // Azure Security Benchmark v3
                },
                {
                    "shortName": "NIST 800-171",
                    "id": "/providers/Microsoft.Authorization/policySetDefinitions/03055927-78bd-4236-86c0-f36125a10dc9" // NIST SP 800-171 Rev. 2
                },
                {
                    "shortName": "NIST 800-53",
                    "id": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f" // NIST SP 800-53 Rev. 5
                },
                {
                    "shortName": "ORG",
                    "id": "/providers/Microsoft.Management/managementGroups/Contoso-Root/providers/Microsoft.Authorization/policySetDefinitions/org-security-benchmark" // Organization Security Benchmark for Custom Policies
                }
            ],
            "environmentColumnsInCsv": [
                "prod",
                "test",
                "dev",
                "lab"
            ]
        }
    ]
}
```

## Example Documentation Specification File using 'environmentCategories'

Each file must contain one or both documentation topics. This example file in the StarterKit has both topics. The element `pacEnvironment` references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the custom Policies and Policy Sets are deployed.

* [`documentAssignments`](#assignment-documentation)
* [`documentPolicySets`](#policy-set-documentation)

```json
{
    "documentAssignments": {
        "environmentCategories": [
            {
                "pacEnvironment": "tenant",
                "environmentCategory": "prod",
                "scopes": [ // Used in Markdown output only
                    "Management Groups: Contoso-Prod"
                ],
                "representativeAssignments": [
                    {
                        "shortName": "ASB",
                        "id": "/providers/Microsoft.Management/managementGroups/Contoso-Prod/providers/Microsoft.Authorization/policyAssignments/prod-asb"
                    },
                    {
                        "shortName": "ORG",
                        "id": "/providers/Microsoft.Management/managementGroups/Contoso-Prod/providers/Microsoft.Authorization/policyAssignments/prod-org"
                    }
                ]
            },
            {
                "pacEnvironment": "tenant",
                "environmentCategory": "test",
                "scopes": [ // Used in Markdown output only
                    "Management Groups: Contoso-NonProd"
                ],
                "representativeAssignments": [
                    {
                        "shortName": "ASB",
                        "id": "/providers/Microsoft.Management/managementGroups/Contoso-NonProd/providers/Microsoft.Authorization/policyAssignments/prod-asb"
                    },
                    {
                        "shortName": "ORG",
                        "id": "/providers/Microsoft.Management/managementGroups/Contoso-NonProd/providers/Microsoft.Authorization/policyAssignments/prod-org"
                    }
                ]
            },
            {
                "pacEnvironment": "tenant",
                "environmentCategory": "dev",
                "scopes": [ // Used in Markdown output only
                    "Management Groups: Contoso-Dev"
                ],
                "representativeAssignments": [
                    {
                        "shortName": "ASB",
                        "id": "/providers/Microsoft.Management/managementGroups/Contoso-Dev/providers/Microsoft.Authorization/policyAssignments/prod-asb"
                    },
                    {
                        "shortName": "ORG",
                        "id": "/providers/Microsoft.Management/managementGroups/Contoso-Dev/providers/Microsoft.Authorization/policyAssignments/prod-org"
                    }
                ]
            }
        ]
    },
    "documentationSpecifications": [
        {
            "fileNameStem": "contoso-policy-effects-across-environments",
            "environmentCategories": [
                "prod",
                "test",
                "dev"
            ],
            "title": "Contoso Policy effects",
            "markdownAdoWiki": true,
            "markdownIncludeComplianceGroupNames": true,
            "markdownSuppressParameterSection": false,
            "markdownMaxParameterLength": 42, //default is 42
            "markdownAdoWikiConfig": [
                {
                    "adoOrganization": "MyOrganization",
                    "adoProject": "EPAC",
                    "adoWiki": "EPAC"
                }
            ]
        }
    ],
    "documentPolicySets": [
        {
            "pacEnvironment": "tenant",
            "fileNameStem": "contoso-compliance-policy-sets",
            "title": "Document interesting Policy Sets",
            "policySets": [
                {
                    "shortName": "ASB",
                    "id": "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8" // Azure Security Benchmark v3
                },
                {
                    "shortName": "NIST 800-171",
                    "id": "/providers/Microsoft.Authorization/policySetDefinitions/03055927-78bd-4236-86c0-f36125a10dc9" // NIST SP 800-171 Rev. 2
                },
                {
                    "shortName": "NIST 800-53",
                    "id": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f" // NIST SP 800-53 Rev. 5
                },
                {
                    "shortName": "ORG",
                    "id": "/providers/Microsoft.Management/managementGroups/Contoso-Root/providers/Microsoft.Authorization/policySetDefinitions/org-security-benchmark" // Organization Security Benchmark for Custom Policies
                }
            ],
            "environmentColumnsInCsv": [
                "prod",
                "test",
                "dev",
                "lab"
            ]
        }
    ]
}
```

## Modifying the Markdown Output

Markdown processors vary slightly. This script has settings to tune the output to match the Markdown processor you are using.

### Azure DevOps Wiki Markdown

* Some Markdown processors (including Azure DevOps Wikis) recognize `[[_TOC_]]` to insert a table of contents. Setting to `markdownAddToc` to `true` enables generating the table of contents.
* Azure DevOps Wikis do not need a heading (title) at level 1. It needs the subheadings at level 1 instead. Setting `markdownAdoWiki` to true enables formatting the headings for Azure DevOps Wiki and generating the table of contents (implicitly sets `markdownAddToc` to `true`).

```jsonc
"markdownAddToc": true, // default is false, set to true to add a table of contents
```

```jsonc
"markdownAdoWiki": true, // default is false, set to true to format headings for Azure DevOps Wiki and generate a table of contents
```

### Automating Azure DevOps Wiki Markdown

* EPAC can be used to automate the population of your Azure DevOps Wiki pages with the generated markdown files. To do this, you must call "Build-PolicyDocumentation" with the parameter "WikiClonePat". The parameter's value should be the name of the Personal Access Token (PAT) set in your pipeline variable. Example:

```
Build-PolicyDocumentation.ps1 -WikiClonePat $(WikiClonePat)
```

* This PAT only requires "Read & write" permissions for "Code", as it will modify and push these markdown files to your Wiki. For more information, please see ["Azure DevOps: Use personal access tokens"](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows)

* To ensure your EPAC reaches your Wiki, you must configure the "markdownAdoWikiConfig" property within your policy documentation file.
  * **adoOrganization**: Name of your ADO Organization
  * **adoProject**: Name of your ADO Project
  * **adoWiki**: Name of your Wiki (If Wiki was not manually set up, it will be created for you based on the name given here)

```jsonc
"markdownAdoWikiConfig": [
                    {
                        "adoOrganization": "MyOrganization",
                        "adoProject": "EPAC",
                        "adoWiki": "EPAC"
                    }
                ]
```

* For a full implementation using an example pipeline, please see ["EPAC GitHub: epac-dev-pipeline-with-adowiki.yml"](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/StarterKit/Pipelines/GitHubActions/GitHub-Flow-With-ADOWiki/epac-dev-pipeline-with-adowiki.yml)

### Embedded HTML in Markdown Tables

EPAC uses embedded HTML to format Markdown tables. Some Markdown processors, such as SharePoint, do not recognize embedded HTML. Setting `markdownNoEmbeddedHtml` to `true` emits commas `,` instead of the HTML tag `<br/>`.

```jsonc
"markdownNoEmbeddedHtml": true, // default is false, set to true to remove embedded HTML in Markdown tables
```

### Improve Markdown Readability

Policy definition group names are not included in Markdown to reduce clutter. You can include a column by setting `markdownIncludeComplianceGroupNames` to `true`,

```jsonc
"markdownIncludeComplianceGroupNames": true, // default is false, set to true to include compliance group names
```

In some markdown processors, very long parameter names break the display. You can set `markdownSuppressParameterSection` to true to completely suppress the parameter section in the Markdown output.

```jsonc
"markdownSuppressParameterSection": true, // default is false, set to true to suppress the parameter section in the Markdown output
```

Alternatively, you can set `markdownMaxParameterLength` to a maximum length. EPAC will truncate the name at that length and append an ellipsis. The default is 42 characters. The minimum is 16 characters.

```jsonc
"markdownMaxParameterLength": 42, // default is 42
```

## Assignment Documentation

### OPTION 1: Element `documentAllAssignments`

Best used when **all** Policy Assignments need to be documented.

When enabled, this section lists all Policy Assignments across all scopes where Policy is directly assigned. In many organizations, the same Policies and effects are applied to multiple Management Groups and even Azure tenants with the parameters consistent, therefore there is an option to group scopes by environment category.

`documentAllAssignments` entry specifies:

* `pacEnvironment`: references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policies and Policy Sets are deployed.
* `fileNameStemPrefix`: add a prefix to the fileNameStem set in "documentationSpecifications". Useful when needing to avoid overwriting files.
* `skipPolicyAssignments`: list of Policy Assignment ID's used to define Policy Assignments that do not want to be included in the output.
* `skipPolicyDefinitions`: list of Policy Definition and Policy Set ID's used to define Policy Assignments that do not want to be included in the output.
* `overrideEnvironmentCategory`: list of custom-defined Environment Categories that will overwrite the auto-generated values. By default, all Policy Assignment scopes are treated as an individual "Environment Category", therefore leverage this section to override these Environment Categories and create custom groupings. (For an example see [`Example Documentation Specification File using 'documentAllAssignments'`](#example-documentation-specification-file-using-documentallassignments))

### Element `documentationSpecifications`

Each entry in the array defines a set of outputs:

* `fileNameStem`: the file name stem used to construct the filenames.
* `environmentCategories` listed as effect columns.
* `title`: Heading 1 text for Markdown.

### OPTION 2: Element `environmentCategories`

Best used when specific Policy Assignments need to be documented.

For any given environment category, such as `prod`, `test`, `dev`, this section lists Policy Assignments which are representative of those environments. In many organizations, the same Policies and effects are applied to multiple Management Groups and even Azure tenants with the parameters consistent by environment category.

Each `environmentCategories` entry specifies:

* `pacEnvironment`: references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policies and Policy Sets are deployed.
* `environmentCategory`: name used for column headings and referenced in `documentationSpecifications` below.
* `scopes`:  used in Markdown output only for the Scopes section as unprocessed text.
* `representativeAssignments`: list Policy Assignment `id`s representing this `environmentCategory`. The `shortName` is used for CSV column headings and markdown output.

### Element `documentationSpecifications`

Each entry in the array defines a set of outputs:

* `fileNameStem`: the file name stem used to construct the filenames.
* `environmentCategories` listed as effect columns.
* `title`: Heading 1 text for Markdown.

### Output files

* `<fileNameStem>-full.csv`: Lists Policies across environments and multiple Policy Sets sorted by `category` and ``displayName`.

    | Column | Description |
    | :----- | :---------- |
    | `name` | Policy name (must be unique - a GUID for built-in Policies)
    | `referencePath` | Disambiguate Policies included multiple times in a Policy Set definition with different `referenceId`s. It is blank if not needed or formatted as `<policy-set.name>\\<referenceId>`.
    | `category` | Policy `category` from Policy `metadata`.
    | `displayName` |
    | `description` |
    | `groupNames` | Union of (compliance Policy Sets) `groupNames` for this Policy.
    | `allowedEffects` | List of allowed Policy `effect`s. **Note:** Some Policy Sets may have hardcoded the effect which is not represented here.
    | `<environmentCategory>_Effect` | One column per `environmentCategory` listing the highest enforcement level across the Policy Sets assigned in this environment category.
    | `<environmentCategory>_Parameters` | One column per `environmentCategory` listing the parameters (JSON - excluding the effect parameter) for this Policy and `environmentCategory`.
    | `<environmentCategory>-`<br/>`<policy-set-short name>-Effect` | Detailed effect per `environmentCategory` **and** Policy Set. The next table shows examples of the different patterns for this value. An actual document will reflect the actual value in your environment.
    | `<policy-set-short name>-ParameterDefinitions` | Parameter definitions (JSON) per Policy Set containing this Policy.

    Examples of effects:

    | Value | Description |
    | :---- | :---------- |
    | `Deny (assignment: secretsExpirationSetEffect)` | Effect is `Deny` specified in a user-defined value for parameter `secretsExpirationSetEffect`
    | `Audit (default: useRbacRulesMonitoringEffect)` | Effect is `Audit` default value for Policy Set parameter `useRbacRulesMonitoringEffect`.
    | `Audit (Initiative Fixed)` | Effect is parameterized in the Policy definition. Policy Set definition is setting it to a fixed value of `Audit`.
    | `Audit (Policy Default)` | Effect is parameterized in Policy definition with a default value of `Audit`. The Policy Set definition does not override or surface this value.
    | `Modify (Policy Fixed)` | Effect is **not** parameterized in Policy definition. It is set to a fixed value of `Modify`.

* `<fileNameStem>-parameters.csv`: This file is intended **for a future enhancement** to EPAC which will allow the effect values and parameter values to be specified in a spreadsheet instead of JSON. This file is generated to make it usable as the starting list, or to round-trip the values. It lists Policies across environments and Initiatives sorted by `category` and ``displayName`. Columns (see above for descriptions):

  * `name`
  * `referencePath`
  * `category` (not required to define the parameters - useful for the author of the spreadsheet)
  * `displayName` (not required to define the parameters - useful for the author of the spreadsheet)
  * `description` (not required to define the parameters - useful for the author of the spreadsheet)
  * `allowedEffects` (not required to define the parameters - useful for the author of the spreadsheet)
  * `<environmentCategory>_Effect`
  * `<environmentCategory>_Parameters`

* `<fileNameStem>-summary.md`: This Markdown file is intended for developers for a quick overview of the effects and parameters in place for each `environmentCategory`. It does not provide details about the individual Initiatives assigned. It is equivalent to `<fileNameStem>-parameters.csv`. The Policies are sorted by `category` and `displayName`. Each `environmentCategory` column shows the current enforcement level in bold. If the value is fixed, the value is also in italics. If it is parametrized, the other allowed values are shown in italics.

* `<fileNameStem>-full.md`: This Markdown file is intended for security teams requiring more details about the Assignments and Policies. It displays the same information as the summary plus the additional details equivalent to `<fileNameStem>-full.csv`. The Policies are sorted by `category` and `displayName`. Each `environmentCategory` column shows the current enforcement level in bold. If the value is fixed, the value is also in italics. If it is parametrized, the other allowed values are shown in italics. The additional details are:
  * Group Names
  * Effects per `environmentCategory` and Policy Set with additional details on the origin of the effect.

* `Folder: services`: Individual Markdown files generated off of the main Policy Assignment Markdown file. These files are based on each "Service Category" and can be used as sub-pages with Azure DevOps Wiki pages.

## Policy Set Documentation

Compares multiple Policy Set definitions for Policy and effect overlap as Markdown and Excel (`.csv`) files.

### Element `documentPolicySets`

* `pacEnvironment`: references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policy and Policy Set definitions are deployed.
* `fileNameStem`: the file name without the extension (.md, .csv, .jsonc)
* `title`: Heading 1 text for Markdown.
* `policySets`: list Policy Sets (`id`) to be compared and included in the parameter JSON file. The `shortName` is used for column headings.
* `environmentColumnsInCsv`: list of columns to generate a parameter file starter equivalent to `<fileNameStem>-parameters.csv` above in the assignment documentation section.

### Output files

* `<fileNameStem>-full.md`: Markdown file with Policies sorted by Policy category and display name with effect columns for each Initiative.

  * Each effect column starts with the bolded display Name followed by the description and lines grouped by bolded Initiative short name with the effect parameter name in italics and the group names in normal text.
  * The text below the description contains details on parameters and group names for each initiative.

* `<fileNameStem>-full.csv`: Excel file with the same information as the Markdown file.
* `<fileNameStem>-parameters.csv`: Excel parameter file starter equivalent to `<fileNameStem>-parameters.csv` above in the assignment documentation section.
* `<fileNameStem>.jsonc`: Parameter file starter in JSON format to simplify parameter settings for Assignments (traditional approach).
