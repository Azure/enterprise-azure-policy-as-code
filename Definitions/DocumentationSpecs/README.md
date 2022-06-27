# Documenting Assignments and Initiatives

## Table of Contents

- [Documentation Specification Files](#documentation-specification-files)
- [Example File](#example-documentation-specification-file)
- [Specifying Assignment Documentation](#specifying-assignment-documentation)
- [Specifying Initiative Documentation](#specifying-initiative-documentation)
- [Reading List](#reading-list)

## Overview

The names of the definition Json files don't matter. reads any file in the folder with a `.json` and `.jsonc` extension.

Script [`./Scripts/Operations/Build-PolicyAssignmentDocumentation.ps1`](../../Scripts/Operations/README.md#build-policyassignmentdocumentationps1) documents Initiatives and Assignments in your environment. It retrieves its instruction from Json files in this folder.

- Read and process Policy Assignments representative of an environment category, such as PROD, DEV, SANDBOX. It generates Markdown and as Excel csv files.
- Read and process Initiative definitions to compare them for Policy and effect overlap.  It generates Markdown and as Excel csv files. Additionaly, it generates a Json file (`.jsonc`) defining all the parameters for the union of Policies in the Initiatives. This Json file is useful when writting assignment files to copy/paste/modify the parameter values.

<br/>

## Example Documentation Specification File

Each file must contain one or both documentation topics. This example file has both topics. Element `pacEnvironment` references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policy and Initiative definitions are deployed.

- [`documentAssignments`](#specifying-assignment-documentation)
- [`documentInitiatives`](#specifying-initiative-documentation)

<br/>

```jsonc
{
    "documentAssignments": {
        "environmentCategories": [
            {
                "pacEnvironment": "tenant1",
                "environmentCategory": "PROD",
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
                "pacEnvironment": "tenant1",
                "environmentCategory": "NONPROD",
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
                "pacEnvironment": "tenant1",
                "environmentCategory": "DEV",
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
                "fileNameStem": "contoso-PROD-policy-effects",
                "type": "effectsPerEnvironment",
                "environmentCategory": "PROD",
                "title": "Contoso PROD environments Policy effects"
            },
            {
                "fileNameStem": "contoso-NONPROD-policy-effects",
                "type": "effectsPerEnvironment",
                "environmentCategory": "NONPROD",
                "title": "Contoso NONPROD environment Policy effects"
            },
            {
                "fileNameStem": "contoso-DEV-policy-effects",
                "type": "effectsPerEnvironment",
                "environmentCategory": "DEV",
                "title": "Contoso DEV environment Policy effects"
            },
            {
                "fileNameStem": "contoso-policy-effects-across-environments",
                "type": "effectsAcrossEnvironments",
                "environmentCategories": [
                    "PROD",
                    "NONPROD",
                    "DEV"
                ],
                "title": "Contoso Policy effects summary"
            }
        ]
    },
    "documentInitiatives": [
        {
            "pacEnvironment": "tenant1",
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
            ]
        }
    ]
}
```

<br/>

## Specifying Assignment Documentation

### Element `environmentCategories`

For any given environment category, such as PROD, NONPROD, DEV, this section list Policy Assignment which are representative deployed in thos environments. In many organization, the same Policies and effects are applied to multiple Management Groups and even Azure tenants.

Each `environmentCategories` entry specifies:

- `pacEnvironment`: references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policy and Initiative definitions are deployed.
- `environmentCategory`: name used for column headings.
- `scopes`:  used in Markdown output only for the Scopes section.
- `representativeAssignments`: list Policy Assignment `id`s representing this `environmentCategory`. The `shortName` is used for column headings.

<br/>

### Element `documentationSpecifications`

This element defines the outputs. Each entry defines the output of one (1) Markdown and one (1) csv file.

- `fileNameStem`: the file name without the extension (.md, .csv)
- `type`: two documentation types are supported.
  - `effectsPerEnvironment`: requires a single `environmentCategory`
    - Creates a Markdown file with Policies grouped by effect, sorted by Policy category and display name with effect columns for each Initiative in the representative Assignments. The effective effect is bolded and the other allowed values are listed in the same cell one per line. **No allowed values listed indicate a hard-coded effect.**
    - Creates a csv file with Policies sorted by Policy category and display name with effect columns for each Initiative in the representative Assignments. The effective effect is listed first and the other allowed values are listed in the same cell one per line.
  - `effectsAcrossEnvironments`: compares the most stringent effect from the Assignments across all `environmentCategories` listed as effect columns.
- `title`: Heading 1 text for Markdown.

<br/>

## Specifying Initiative Documentation

Compares Policy and Initiative definitions to  Initaitive Definitions for Policy and effect overlap as Markdown and as Excel csv files.

Craete a Json file (`.jsonc`) defining all the parameters as Json for the union of Policies in the defined Initiative Definitions sorted an colated by Policy category and Policy display name. This Json file is useful when writting assignment files. You can use them with copy/paste and modify the parameter values in your assignment file(s).

Each array entry defines three (3) files to be generated: Markdown, csv, and Json paramter file (.jsonc)

- `pacEnvironment`: references the Policy as Code environment in `global-settings.jsonc` defining the tenant and root scope where the Policy and Initiative definitions are deployed.
- `fileNameStem`: the file name without the extension (.md, .csv, .jsonc)
- `title`: Heading 1 text for Markdown.
- `initiatives`: list Initiatives (`id`) to be compared and included in the parameter Json file. The `shortName` is used for column headings.

<br/>

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Documenting Assignments and Initiatives](../../Definitions/DocumentationSpecs/README.md)**

1. **[Operational Scripts](../../Scripts/Operations/README.md)**

**[Return to the main page](../../README.md)**
<br/>
