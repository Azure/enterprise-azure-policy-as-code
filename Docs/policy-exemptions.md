# Exemptions

**On this page**

* [Exemption Files](#exemption-files)
  * [JSON Format](#json-format)
  * [CSV/XLSX Format](#csvxlsx-format)
* [Reading List](#reading-list)

## Exemption Files

Exemptions can be defined as JSON or CSV files. The names of the definition files don't matter.

Additionally, through the use of a third-party PowerShell module from the PowerShell Gallery `ImportExcel` (<https://www.powershellgallery.com/packages/ImportExcel>, <https://github.com/dfinke/ImportExcel/tree/master/Public>). The contributors to this project are not responsible for any issues with that module. To mitigate the risk, the StarterKit has commented out the use of the conversion to protect your system from any vulnerabilities and executes the script without an Azure login.

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

* Column headers must be exactly as the JSON labels above.
* `policyDefinitionReferenceIds` use comma separated list within each cell.
* `metadata` cells must contain valid JSON.

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

**[Return to the main page](../README.md)**
