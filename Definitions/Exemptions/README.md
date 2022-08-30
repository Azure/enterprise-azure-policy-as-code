# Exemptions

## Table of Contents

- [Exemption Files](#exemption-files)
- [Example](#example)
- [Reading List](#reading-list)

## Exemption Files

Exemptions can be defined as JSON or CSV files. The names of the definition files don't matter.

Additionally, through the use of a third-party PowerShell module from the PowerShell Gallery `ImportExcel` (https://www.powershellgallery.com/packages/ImportExcel, https://github.com/dfinke/ImportExcel/tree/master/Public). The contributors to this project are not responsible for any issues with that module. To mitigate the risk, the StarterKit has commented out the use of the conversion to protect your system from any vulnerabilities and executes the script without an Azure login.

The pacEnvironment (see global-settings.jsonc) is represented with a folder, such as dev, test, tenant, ... A missing folder indicates that the pacEnvironment's Exemptions are managed by this solution. To extract existing extension, the operations script Get-AzExemptions.ps1 can be used to generate JSON and CSV files. The output should be used to start the Exemption definitions.

### JSON Format

`name`, `displayName`, `exemptionCategory`, `scope` and `assignmentId` are required fields. The others are optional.

```jsonc
{
    "exemptions": [
        {
            "name": "Unique name",
            "displayName": "Descriptive name displayed on portal",
            "description": "More details",
            "exemptionCategory": "waiver",
            "scope": "/subscriptions/11111111-2222-3333-4444-555555555555",
            "policyAssignmentId": "/providers/microsoft.management/managementgroups/contoso-prod/providers/microsoft.authorization/policyassignments/prod-asb",
            "policyDefinitionReferenceIds": [
                "webApplicationFirewallShouldBeEnabledForApplicationGatewayMonitoringEffect"
            ],
            "metadata": {
                "custom": "value"
            }
        }
    ]
}
```

### CSV/XLSX Format
If you use spreadsheets (.csv or .xlsx):
- Column headers must be exactly as the JSON labels above.
- `policyDefinitionReferenceIds` use comma separated list within each cell.
- `metadata` cells must contain valid JSON.

<br/>

## Reading List

1. **[Pipeline](../../Pipeline/README.md)**

1. **[Update Global Settings](../../Definitions/README.md)**

1. **[Create Policy Definitions](../../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](#initiative-definitions)**

1. **[Define Policy Assignments](../../Definitions/Assignments/README.md)**

1. **[Documenting Assignments and Initiatives](../../Definitions/Documentation/README.md)**

1. **[Operational Scripts](../../Scripts/Operations/README.md)**

**[Return to the main page](../../README.md)**
<br/>
