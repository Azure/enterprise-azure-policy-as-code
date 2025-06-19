
# Policy Assignment Parameters from a CSV File

Assigning single or multiple security and compliance focused Policy Sets (Initiatives), such as Microsoft cloud security benchmark, NIST 800-53 R5, PCI, NIST 800-171, etc, with just JSON parameters becomes very complex fast. Add to this the complexity of overriding the effect if it is not surfaced as a parameter in the `Policy Set`. Finally, adding the optional `nonComplianceMessages` further increases the complexity.

To address the problem of reading and maintaining hundreds or thousands of JSON lines, EPAC can use the content of a spreadsheet (CSV) to create `parameters`, `overrides` and optionally `nonComplianceMessages` for a single Policy assignment `definitionEntry` or multiple Policy definitions (`definitionEntryList`).

> [!TIP]
> This approach is best for large Policy Sets such as Azure Security Benchmark, NIST 800-53, etc. Smaller Policy Sets should still be handled with JSON `parameters`, `overrides` and `nonComplianceMessages`.

## Generate the CSV File

### From a list of Policy Sets

[Generating documentation for one or more Policy Sets](operational-scripts-documenting-policy.md#policy-set-documentation), then modify the effect and parameter columns for each environment type you will use.

### From a list of deployed Policy Assignments

If you want to switch from JSON to CSV or start EPAC from an existing deployment, [generate this CSV file frm your already deployed Assignment(s)](operational-scripts-documenting-policy.md#assignment-documentation).

## CSV File

In the example header below the infrastructure environments prod, test, dev, and sandbox are used as prefixes to the columns for Effect and Parameters respectively. Optionally you can add a column for `nonComplianceMessages`

The CSV file generated contains the following headers/columns:

* `name` is the name of the policyDefinition referenced by the Policy Sets being assigned.
* `referencePath` is only used if the Policy is used more than once in at least one of the Policy Sets to disambiguate them. The format is `<policySetName>//<policyDefinitionReferenceId>`.
* `policyType`,`category`,`displayName`,`description`,`groupNames`,`policySets`,`allowedEffects` are optional and not used for deployment planning. They assist you in filling out the `<env>Effect` columns. The CSV file is sorted alphabetically by `category` and `displayName`.
* `<env>Effect` columns must contain one of the allowedValues or allowedOverrides values. You define which scopes define each type of environment and what short name you give the environment type to use as a column prefix.
* `<env>Parameters` can contain additional parameters. You can also specify such parameters in JSON. EPAC will use the union of all parameters.
* `nonComplianceMessages` column is optional. The documentation script does not generate this column.

> [!NOTE]
> Additional columns are allowed and ignored by EPAC.

EPAC will find the effect parameter name for each Policy in each Policy Set and use them. If no effect parameter is defined by the Policy Set, EPAC will use `overrides` to set the effect. EPAC will generate the `policyDefinitionReferenceId` for `nonComplianceMessages`.

After building the spreadsheet, you must reference the CSV file and the column prefix in each tree branch. `parameterFile` must occur once per tree branch. Define it adjacent to the `'definitionEntry` or `definitionEntryList` to improve readability.

```json
"parameterFile": "security-baseline-parameters.csv",
"definitionEntryList": [
    {
        "policySetName": "1f3afdf9-d0c9-4c3d-847f-89da613e70a8",
        "displayName": "Azure Security Benchmark",
        "assignment": {
            "append": true,
            "name": "asb",
            "displayName": "Azure Security Benchmark",
            "description": "Azure Security Benchmark Initiative. "
        }
    },
    {
        "policySetName": "179d1daa-458f-4e47-8086-2a68d0d6c38f",
        "displayName": "NIST SP 800-53 Rev. 5",
        "assignment": {
            "append": true,
            "name": "nist-800-53-r5",
            "displayName": "NIST SP 800-53 Rev. 5",
            "description": "NIST SP 800-53 Rev. 5 Initiative."
        }
    }
],
```

In the child nodes specifying the scope(s) specify which column prefix to use for selecting the CSV columns with `parameterSelector`. The actual prefix names have no meaning; they only need to match between the JSON below and the CSV file.

```json
{
    "nodeName": "Prod/",
    "assignment": {
        "name": "pr-",
        "displayName": "Prod ",
        "description": "Prod Environment controls enforcement with initiative "
    },
    "parameterSelector": "prod",
    "scope": {
        "epac-dev": [
            "/providers/Microsoft.Management/managementGroups/Epac-Mg-Prod"
        ],
        "tenant": [
            "/providers/Microsoft.Management/managementGroups/Contoso-Prod"
        ]
    }
},
```

The element `nonComplianceMessageColumn` may appear anywhere in the tree. Definitions at a child override the previous setting. If no `nonComplianceMessageColumn` is specified, the spreadsheet is not used for the (optional) `nonComplianceMessages`.

```json
{
    "nodeName": "Prod/",
    "assignment": {
        "name": "pr-",
        "displayName": "Prod ",
        "description": "Prod Environment controls enforcement with initiative "
    },
    "parameterSelector": "prod",
    "nonComplianceMessageColumn": "nonComplianceMessages"
    "scope": {
        "epac-dev": [
            "/providers/Microsoft.Management/managementGroups/Epac-Mg-Prod"
        ],
        "tenant": [
            "/providers/Microsoft.Management/managementGroups/Contoso-Prod"
        ]
    }
},
```

## Effects for `definitionEntryList` Policy Sets with Overlapping Policies

Policy Set definitions often have a large overlap. In CSV files the Policy only shows up once. When EPAC processes the CSV file, it will use the effect from the first Policy Set definition in the `definitionEntryList` that contains the Policy.

For the next Policy Set in the `definitionEntryList` that contains the same Policy, EPAC will adjust the effect:
- `Append`, `Modify` and `Deny` will be adjusted to `Audit`
- `DeployIfNotExists` will be adjusted to `AuditIfNotExists`

## Updating the CSV File

Policy Set definitions for built-in or custom Policy Sets are sometimes updated. When this happens, the CSV file must be updated to reflect the changes. EPAC displays a Warning  when this happens.

### Policy Removed (Policy from Row in the CSV File is not used in any Policy Set)

If a Policy is removed from every Policy Set, remove the row from the spreadsheet or regenerate the CSV file from the deployed Policy Assignments.

### Policy Added (Policy Entry is missing in the CSV file)

If a Policy is added to a Policy Set, add the row manually to the CSV file. The Policy will be assigned with the default effect.

Better, [regenerate the CSV file from the deployed Policy Assignments](operational-scripts-documenting-policy.md#assignment-documentation). This will ensure that all Policies are included in the CSV file. However, this does not generate the `nonComplianceMessages` column or any additional columns you added.

> [!NOTE]
> We have planned to add a feature to generate the CSV file from the Policy Assignments and merge them with your existing CSV File to preserve extra columns.
