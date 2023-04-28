# Exemptions

## Exemption Files

Exemptions can be defined as JSON or CSV files (we recommend that you use CSV files). The names of the definition files don't matter. If multiple files exists in a folder, the lists from all the files are added together.

The pacEnvironment (see global-settings.jsonc) is represented with a folder structure under the folder policyExemptions, such as epac-dev, tenant, ... A missing folder indicates that the pacEnvironment's Exemptions are not managed by this solution. To extract existing exemptions, the operations script Get-AzExemptions.ps1 can be used to generate JSON and CSV files. The output may be used to start the Exemption definitions. This same output is also created when [Extract existing Policy Resources from an Environment](extract-existing-policy-resources.md).

A typical folder structure might look like this:

```
Definitions
  policyExemptions
    epac-dev
      <name>.csv of <name>.json
    tenant
      <name>.csv of <name>.json
```

## CSV Format

We recommend that you use spreadsheets (`.csv`). The columns must have the following headers:

* `name` - unique name.
* `displayName` - descriptive name displayed on portal.
* `exemptionCategory` - `waiver` or `mitigated`.
* `expiresOn` - empty or expiry date.
* `scope` - Management Group, subscription, Resource Group or resource.
* `assignmentId` - fully qualified assignment id.
* `policyDefinitionReferenceIds` use comma separated list within each cell.
* `metadata` - valid JSON (see JSON format below)

## JSON Format

`name`, `displayName`, `exemptionCategory`, `scope` and `assignmentId` are required fields. The others are optional.

```json
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
