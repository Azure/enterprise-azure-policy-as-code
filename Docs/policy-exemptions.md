# Exemptions

## Table of Contents

* [Exemption Files](#exemption-files)
  * [JSON Format](#json-format)
  * [CSV/XLSX Format](#csvxlsx-format)
* [Reading List](#reading-list)

## Exemption Files

Policy exemptions are managed within the EPAC solution by adding the folder `policyExemptions` under `Definitions`.  Within folder `policyExemptions`, exemptions for each pac environment (defined in global-settings.jsonc) are maintained in a matching folder, such as `epac-dev`, `epac-test`, and `tenant`.  If `policyExemptions` folder or indivudual epac environment folders are not present, it means policy exemptions are not managed by the EPAC solution.   

Exemptions can be defined as JSON or CSV files. The names of the definition files don't matter.  To extract existing exemptions, the operations script Get-AzExemptions.ps1 can be used to generate JSON and CSV files. The output should be used to start the Exemption definitions.

Additionally, through the use of a third-party PowerShell module from the PowerShell Gallery `ImportExcel` (https://www.powershellgallery.com/packages/ImportExcel, https://github.com/dfinke/ImportExcel/tree/master/Public), .xlsx files can be used to manage exemptions. 

 > **NOTE**: The contributors to this project are not responsible for any issues with the `ImportExcel` module. To mitigate the risk, the StarterKit has commented out the use of the conversion to protect your system from any vulnerabilities and executes the script without an Azure login.


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

## Reading List

* [Pipeline - Azure DevOps](azure-devops-pipeline.md)
* [Update Global Settings](definitions-and-global-settings.md)
* [Create Policy Definitions](policy-definitions.md)
* [Create Policy Set (Initiative) Definitions](policy-set-definitions.md)
* [Define Policy Assignments](policy-assignments.md)
* [Define Policy Exemptions](policy-exemptions.md)
* [Documenting Assignments and Initiatives](documenting-assignments-and-policy-sets.md)
* [Operational Scripts](operational-scripts.md)
* **[Cloud Adoption Framework Policies](cloud-adoption-framework.md)**

**[Return to the main page](../README.md)**
