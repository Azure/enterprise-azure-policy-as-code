# Documenting Assignments and Initiatives

## Table of Contents

* [Overview](#overview)
* [Example Documentation Specification File](#example-documentation-specification-file)
* [Assignment Documentation](#assignment-documentation)
  * [Element `environmentCategories`](#element-environmentcategories)
  * [Element `documentationSpecifications`](#element-documentationspecifications)
  * [Output files](#output-files)
* [Initiative Documentation](#initiative-documentation)
  * [Element `documentInitiatives`](#element-documentinitiatives)
  * [Output files](#output-files-1)
* [Reading List](#reading-list)

## Overview

The names of the definition JSON files don't matter. The script reads any file in the folder with a `.json` and `.jsonc` extension.

Script [`./Scripts/Operations/Build-PolicyAssignmentDocumentation.ps1`](../../Scripts/Operations/README.md#build-policyassignmentdocumentationps1) documents Initiatives and Assignments in your environment. It retrieves its instruction from the JSON files in this folder.

- Read and process Policy Assignments which are representative of an environment category, such as prod, test, dev, and sandbox. It generates Markdown (`.md`), and Excel (`.csv`) files.
- Read and process Initiative definitions to compare them for Policy and effect overlap. It generates Markdown (`.md`), Excel (`.csv`) files, and JSON file (`.jsonc`).

<br/>

## Example Documentation Specification File

Each file must contain one or both documentation topics. This example file in the StarterKit has both topics. Element `pacEnvironment` references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the custom Policy and Initiative definitions are deployed.

- [`documentAssignments`](#specifying-assignment-documentation)
- [`documentInitiatives`](#specifying-initiative-documentation)

<br/>

```jsonc
{
    "documentAssignments": {
        "environmentCategories": [
            {
                "pacEnvironment": "tenant",
                "environmentCategory": "PprodOD",
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
            },
        ],
        "documentationSpecifications": [
            {
                "fileNameStem": "contoso-policy-effects-across-environments",
                "environmentCategories": [
                    "prod",
                    "test",
                    "dev"
                ],
                "title": "Contoso Policy effects"
            }
        ]
    },
    "documentInitiatives": [
        {
            "pacEnvironment": "tenant",
            "fileNameStem": "contoso-compliance-initiatives",
            "title": "Document interesting Initiatives",
            "initiatives": [
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

<br/>

## Assignment Documentation

### Element `environmentCategories`

For any given environment category, such as `prod`, `test`, `dev`, this section list Policy Assignment which are representative for those environments. In many organization, the same Policies and effects are applied to multiple Management Groups and even Azure tenants with the parameters consistent by environment category.

Each `environmentCategories` entry specifies:

- `pacEnvironment`: references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policy and Initiative definitions are deployed.
- `environmentCategory`: name used for column headings and referenced in `documentationSpecifications` below.
- `scopes`:  used in Markdown output only for the Scopes section as unprocessed text.
- `representativeAssignments`: list Policy Assignment `id`s representing this `environmentCategory`. The `shortName` is used for CSV column headings and markdown output.

<br/>

### Element `documentationSpecifications`

<br/>

> **Warning: Breaking change in release v5.3**
>
> `type` is no longer needed and the field has been removed. The only previous `type` available is `effectsAcrossEnvironments`; the script will write a warning if it is specified. Specifying `"type": "effectsPerEnvironment",` will result in a script error.

<br/>

Each entry in the array defines a set of outputs:

- `fileNameStem`: the file name stem used to construct the filenames.
- `environmentCategories` listed as effect columns.
- `title`: Heading 1 text for Markdown.

<br/>

### Output files

- `<fileNameStem>-full.csv`: Lists Policies across environments and Initiatives sorted by `category` and ``displayName`.
  | Column | Description |
  | :----- | :---------- |
  | `name` | Policy name (must be unique - a GUID for built-in Policies)
  | `referencePath` | Disambiguate Policies included multiple times in an Initiative with different `referenceId`s. It is blank if not needed or formatted as `<initiative.name>\\<referenceId>`.
  | `category` | Policy `category` from Policy `metadata`.
  | `displayName` |
  | `description` |
  | `groupNames` | Union of (compliance Initiative) `groupNames` for this Policy.
  | `allowedEffects` | List of allowed Policy `effect`s. **Note:** Some Initiatives may have hard coded the effect which is not represented here.
  | `<environmentCategory>_Effect` | One column per `environmentCategory` listing the highest enforcement level across the initiatives assigned in this environment category.
  | `<environmentCategory>_Parameters` | One column per `environmentCategory` listing the parameters (JSON - excluding the effect parameter) for this Policy and `environmentCategory`.
  | `<environmentCategory>-`<br/>`<initiative-short name>-Effect` | Detailed effect per `eventCategory` **and** Initiative. The next table shows examples for the different pattern for this value. An actual document will reflect the actual value in your environment.
  | `<initiative-short name>-ParameterDefinitions` | Parameter definitions (JSON) per Initiative containing this Policy.
  <br/>

  | Value | Description |
  | :---- | :---------- |
  | `Deny (assignment: secretsExpirationSetEffect)` | Effect is `Deny` specified in a user defined value for parameter `secretsExpirationSetEffect`
  | `Audit (default: useRbacRulesMonitoringEffect)` | Effect is `Audit` default value for Initiative parameter `useRbacRulesMonitoringEffect`.
  | `Audit (Initiative Fixed)` | Effect is parameterized in Policy definition. Initiative definition is setting it to a fixed value of `Audit`.
  | `Audit (Policy Default)` | Effect is parameterized in Policy definition with default value of `Audit`. The Initiative definition does not override or surface this value.
  | `Modify (Policy Fixed)` | Effect is **not** parameterized in Policy definition. It is set to a fixed value of `Modify`.

- `<fileNameStem>-parameters.csv`: This file is intended **for a future enhancement** to EPAC which will allow the effect values and parameter values to be specified in a spreadsheet instead of JSON. This file is generated to make it usable as the starting list, or to round-trip the values. It lists Policies across environments and Initiatives sorted by `category` and ``displayName`. Columns (see above for descriptions):

  - `name`
  - `referencePath`
  - `category` (not required to define the parameters - useful for the author of the spreadsheet)
  - `displayName` (not required to define the parameters - useful for the author of the spreadsheet)
  - `description` (not required to define the parameters - useful for the author of the spreadsheet)
  - `allowedEffects` (not required to define the parameters - useful for the author of the spreadsheet)
  - `<environmentCategory>_Effect`
  - `<environmentCategory>_Parameters`

- `<fileNameStem>-summary.md`: This Markdown file is intended for developers for a quick overview of the effects and parameters in place for each `environmentCategory`. It does not provide details about the individual Initiatives assigned.It is equivalent to `<fileNameStem>-parameters.csv`. The Policies are sorted by `category` and ``displayName`. Each `environmentCategory column shows the current enforcement level in bold. If the value is fixed, the value is also in italics. If it is parametrized, the other allowed values are shown in italics.

- `<fileNameStem>-full.md`: This Markdown file is intended for security personel requiring more details about the Assignments and Policies. It displays the same information as the summary plus the additional details equivalent to `<fileNameStem>-full.csv`. The Policies are sorted by `category` and ``displayName`. Each `environmentCategory column shows the current enforcement level in bold. If the value is fixed, the value is also in italics. If it is parametrized, the other allowed values are shown in italics. The additional details are:
  - Group Names
  - Effects per `environmentCategory` and Initiative with additional details on the origin of the effect.

## Initiative Documentation

Compares Policy and Initiative definitions to  Initiative definitions for Policy and effect overlap as Markdown and Excel (`.csv`) files.

### Element `documentInitiatives`

- `pacEnvironment`: references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policy and Initiative definitions are deployed.
- `fileNameStem`: the file name without the extension (.md, .csv, .jsonc)
- `title`: Heading 1 text for Markdown.
- `initiatives`: list Initiatives (`id`) to be compared and included in the parameter JSON file. The `shortName` is used for column headings.
- `environmentColumnsInCsv`: list of columns to generate a parameter file starter equivalent to `<fileNameStem>-parameters.csv` above in the assignment documentation section.

### Output files

- `<fileNameStem>-full.md`: Markdown file with Policies sorted by Policy category and display name with effect columns for each Initiative.

  - Each effect column starts with the bolded display Name followed by the description and lines grouped by bolded Initiative short name with the effect parameter name in italics and the group names in normal text.
  - The text below the description contains details on parameters and group names for each initiative.

- `<fileNameStem>-full.csv`: Excel file  with the same information as the Markdown file.
- `<fileNameStem>-parameters.csv`: Excel parameter file starter equivalent to `<fileNameStem>-parameters.csv` above in the assignment documentation section.
- `<fileNameStem>.jsonc`: Parameter file starter in JSON format to simplify parameter settings for Assignments (traditional approach).
<br/>

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Define Policy Exemptions](../../Definitions/Exemptions/README.md)**

1. **[Documenting Assignments and Initiatives](../../Definitions/Documentation/README.md)**

1. **[Operational Scripts](../../Scripts/Operations/README.md)**

**[Return to the main page](../../README.md)**
<br/>
