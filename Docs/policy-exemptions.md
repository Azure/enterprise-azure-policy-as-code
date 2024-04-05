# Exemptions

## Exemption Folder Structure

Exemptions can be defined as JSON or CSV files (we recommend that you use CSV files). The names of the definition files don't matter. If multiple files exists in a folder, the lists from all the files are added together.

The pacEnvironment (see global-settings.jsonc) is represented with a folder structure under the folder policyExemptions, such as epac-dev, tenant, ... A missing folder indicates that the pacEnvironment's Exemptions are not managed by this solution. To extract existing exemptions, the operations script Get-AzExemptions.ps1 can be used to generate JSON and CSV files. The output may be used to start the Exemption definitions. This same output is also created when [Extract existing Policy Resources from an Environment](epac-extracting-policy-resources.md).

A typical folder structure might look like this:

```
Definitions
  policyExemptions
    epac-dev
      <name>.csv of <name>.json
    tenant
      <name>.csv of <name>.json
```

## JSON Schema

The GitHub repo contains a JSON schema which can be used in tools such as [VS Code](https://code.visualstudio.com/Docs/languages/json#_json-schemas-and-settings) to provide code completion.

To utilize the schema add a ```$schema``` tag to the JSON file.

```
{
  "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-exemption-schema.json"
}
```

## Defining Exemptions

!!! tip

    In v10.0.0, exemptions can be defined by specifying the Policy definition Ids or Names instead of Policy Assignment Ids. This significantly reduces the complexity of defining exemptions for Policy Sets with overlapping Policy definitions. **We recommend using Policy definition Ids or Names for new exemptions.**

Each exemption must define the following properties:
- `name` - unique name, we recommend a GUID.
- `displayName` - descriptive name displayed on portal.
- `exemptionCategory` - `Waiver` or `Mitigated`.
- Policy or Policies to be exempted
- `scope` - Management Group, subscription, Resource Group or resource.
- `metadata` - valid JSON (see JSON format below)
- Optional
  - `expiresOn` - empty or expiry date.
  - `assignmentScopeValidation` - `Default` or `DoNotValidate`
  - `resourceSelectors` - valid JSON (see JSON format below)

### Specifying Policy or Policies to be Exempted

The following properties can be used to specify the Policy or Policies to be exempted:

- Option **A**: Policy definition Ids or Names (**recommended**)
- Option **B**: Policy Assignment Id and for Policy Sets a list of Policy definition Ids or Names, or policyDefinitionReferenceIds (**legacy - no longer recommended**)
- Option **C**: Policy Set definition Ids or Names and a list of Policy definition Ids or Names, or policyDefinitionReferenceIds (**included for completeness, do not use**)

## Metadata

You can use `metadata` for additional information.

EPAC injects `deployedBy` into the `metadata` section. This is a string that identifies the deployment source. It defaults to `epac/$pacOwnerId/$pacSelector`. You can override this value in `global-settings.jsonc`

**Not recommended:** Adding `deployedBy` to the `metadata` section in the Policy definition file will override the value for this Exemption only from `global-settings.jsonc` or default value.

### CSV Format

The columns must have the headers as described above. The order of the columns is not important.

#### Regular Columns

- `name` - unique name, we recommend a GUID.
- `displayName` - descriptive name displayed on portal.
- `exemptionCategory` - `Waiver` or `Mitigated`.
- `scope` - Management Group, subscription, Resource Group or resource.
- `metadata` - valid JSON (see JSON format below)
- Optional
  - `expiresOn` - empty or expiry date.
  - `assignmentScopeValidation` - `Default` or `DoNotValidate`
  - `resourceSelectors` - valid JSON (see JSON format below)

#### Option A: Policy definition Ids or Names

- Column `assignmentReferenceId` must be formatted:
  - For Built-in Policy definition: `/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000`
  - For Custom Policy definition: `policyDefinitions/{{policyDefinitionName}}`
- Column `policyDefinitionReferenceIds` must be empty

#### Option B: Policy Assignment Id

- Column `assignmentReferenceId` must be a Policy Assignment Id:
  - `/providers/Microsoft.Management/managementGroups/{{managementGroupId}}/providers/Microsoft.Authorization/policyAssignments/{{policyAssignmentName}}`
- Column `policyDefinitionReferenceIds` must be a comma separated list containing any of the following:
  - Empty for Policy Assignment of a single Policy, or to exempt the scope from every Policy in the assigned Policy Set
  - policyDefinitionReferenceId from the assigned Policy Set definition
  - For Built-in Policy definition: `/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000`
  - For Custom Policy definition: `policyDefinitions/{{policyDefinitionName}}`

#### Option C: Policy Set definition Ids or Names

- Column `assignmentReferenceId` must be a Policy Set definition Id or Name:
  - For Built-in Policy Set definition: `/providers/Microsoft.Authorization/policySetDefinitions/00000000-0000-0000-0000-000000000000`
  - For Custom Policy Set definition: `policySetDefinitions/{{policySetDefinitionName}}`
- Column `policyDefinitionReferenceIds` must be a comma separated list containing any of the following:
  - Empty for Policy Assignment of a single Policy, or to exempt the scope from every Policy in the assigned Policy Set
  - policyDefinitionReferenceId from the assigned Policy Set definition
  - For Built-in Policy definition: `/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000`
  - For Custom Policy definition: `policyDefinitions/{{policyDefinitionName}}`

### JSON Format

The fields are the same as the CSV format:

- `name` - unique name, we recommend a GUID.
- `displayName` - descriptive name displayed on portal.
- `exemptionCategory` - `Waiver` or `Mitigated`.
- `scope` - Management Group, subscription, Resource Group or resource.
- `metadata` - valid JSON (see JSON format below)
- Optional
  - `expiresOn` - empty or expiry date.
  - `assignmentScopeValidation` - `Default` or `DoNotValidate`
  - `resourceSelectors` - valid JSON (see JSON format below)

#### Option A: Policy definition Ids or Names

- For built-in Policy definitions: `policyDefinitionId`
- For custom Policy definitions: `policyDefinitionName`
- Omit `policyDefinitionReferenceIds`.

#### Option B: Policy Assignment Id

- `policyAssignmentId` - Policy Assignment Id
- Omit `"policyDefinitionReferenceIds": [ ... ]` for Policy Assignment of a single Policy, or to exempt the scope from every Policy in the assigned Policy Set
- For Policy Set Assignments only: `"policyDefinitionReferenceIds": [ ... ]` containing an array following:
  - policyDefinitionReferenceId from the assigned Policy Set definition
  - For Built-in Policy definition: `"/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000"`
  - For Custom Policy definition: `"policySetDefinitions/{{policySetDefinitionName}}"`

#### Option C: Policy Set definition Ids or Names

- For built-in Policy Set definitions: `policySetDefinitionId`
- For custom Policy Set definitions: `policySetDefinitionName`
- Omit `"policyDefinitionReferenceIds": [ ... ]` to exempt the scope from every Policy in the assigned Policy Set
- To select the Policies within the Policy set to exempt `"policyDefinitionReferenceIds": [ ... ]` containing an array following:
  - policyDefinitionReferenceId from the assigned Policy Set definition
  - For Built-in Policy definition: `"/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000"`
  - For Custom Policy definition: `"policySetDefinitions/{{policySetDefinitionName}}"`

#### Example

```json
{
    "exemptions": [
        {
            "name": "00000000-0000-0000-0000-000000000000",
            "displayName": "Descriptive name displayed on portal",
            "description": "More details",
            "exemptionCategory": "Waiver",
            "scope": "/subscriptions/11111111-2222-3333-4444-555555555555",
            "policyDefinitionId": "/providers/microsoft.authorization/policyDefinitions/00000000-0000-0000-0000-000000000000",
        },
        {
            "name": "00000000-0000-0000-0000-000000000001",
            "displayName": "Descriptive name displayed on portal",
            "description": "More details",
            "exemptionCategory": "Mitigated",
            "scope": "/subscriptions/11111111-2222-3333-4444-555555555555",
            "policyDefinitionName": "policyDefinitionName",
            "expiresOn": "2022-12-31T23:59:59Z",
            "assignmentScopeValidation": "DoNotValidate",
        },
        {
            "name": "00000000-0000-0000-0000-000000000002",
            "displayName": "Descriptive name displayed on portal",
            "description": "More details",
            "exemptionCategory": "Mitigated",
            "scope": "/subscriptions/11111111-2222-3333-4444-555555555555",
            "policyAssignmentId": "/providers/microsoft.authorization/policyAssignments/{{assignmentName}}}}",
            "policyDefinitionReferenceIds": [
                "/providers/microsoft.authorization/policyDefinitions/00000000-0000-0000-0000-000000000000",
                "policyDefinitions/{{policyDefinitionName}}",
                "{{policyReferenceId}}"
            ]
        }
    ]
}
```
