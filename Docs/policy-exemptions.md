# Policy Exemptions

> [!TIP]
> The changes implementing [Option **A** below](#option-a-policy-definition-ids-or-names) makes JSON files easier to read than CSV files. We recommend using **Policy definition Ids or Names** for new exemptions and **JSON** files  instead of CSV files. Of course, CSV files are still supported. You may even mix and match the two formats in the same folder.

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

> [!TIP]
> In v10.0.0, exemptions can be defined by specifying the Policy definition Ids or Names instead of Policy Assignment Ids. This significantly reduces the complexity of defining exemptions for Policy Sets with overlapping Policy definitions. 

Each exemption must define the following properties:

- `name` - unique name, we recommend a short human readable name.
- `displayName` - descriptive name displayed on portal.
- `exemptionCategory` - `Waiver` or `Mitigated`.
- Item to exempt; one of the following:
  - `policyDefinitionId`, or `policyDefinitionName` - exempts the Policy definition in all applicable Policy Assignments.
  - `policySetDefinitionId`, or `policySetDefinitionName` - exempts all Policies in the Policy Set, or a subset if `policyDefinitionsReferenceIds` are specified.
  - `policyAssignmentId`to be exempted. For Assignments of a Policy Set, you may add `policyDefinitionReferenceIds` to exempt specific Policies within the Policy Set.
- `scope` or `scopes` - Management Group, subscription, Resource Group or resource.
- Optional
  - `expiresOn` - empty or expiry date.
  - `assignmentScopeValidation` - `Default` or `DoNotValidate`
  - `resourceSelectors` - valid JSON (see JSON format below)
  - `metadata` - valid JSON (see JSON format below)

### Metadata

You can use `metadata` for additional information.

EPAC injects `deployedBy` into the `metadata` section. This is a string that identifies the deployment source. It defaults to `epac/$pacOwnerId/$pacSelector`. You can override this value in `global-settings.jsonc`

**Not recommended:** Adding `deployedBy` to the `metadata` section in the Policy definition file will override the value for this Exemption only from `global-settings.jsonc` or default value.

## Specifying Policy or Policies to be Exempted

The following properties can be used to specify the Policy or Policies to be exempted.

> [!CAUTION]
> `assignmentScopeValidation` value `DoNotValidate` only works for Option **B**. It may work for Option **A** and **C** in some cases, but it is not recommended. EPAC cannot gracefully handle this and display a specific error message. Instead, it will display a generic error message with the following text `"Exemption entry $($entryNumber): No assignments found for scope $($currentScope), skipping entry."`.

### Option **A**: Policy definition Ids or Names

> [!TIP]
> We recommend using this option for new exemptions, except when exempting multiple Policies in a Policy Set.

It creates one exemption per Assignment containing the Policy definition (direct or indirect through a Policy Sets). `policyDefinitionReferenceIds` must be empty (omitted). This is the simplest and most readable way to define exemptions. Specify one of the following:

- `policyDefinitionId` for built-in Policy definitions in the form `"/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000"`.
- `policyDefinitionName` for custom Policy definitions. In CSV files specify the cell in `assignmentReferenceId` as `"policyDefinitions/{{policyDefinitionName}}"`.

### Option **B**: Policy Assignment Id

It creates one exemption for the specified Policy Assignment. This is the traditional way of defining an Exemption. It is still useful for exempting multiple Policies in an assigned Policy Set with one exemption. Specify the following:

- `policyAssignmentId` for the Policy Assignment in the form `/providers/Microsoft.Management/managementGroups/{{managementGroupId}}/providers/Microsoft.Authorization/policyAssignments/{{policyAssignmentName}}`.
- Optionally, for Policy Set Assignments only, `policyDefinitionReferenceIds` containing an array of [strings as detailed below](#specifying-policydefinitionreferenceids).

In CSV files, the column `policyAssignmentId` is still supported for backward compatibility for **Option B** only.

> [!TIP]
> We recommend using the column `assignmentReferenceId` for every options, including option **B**.

### Option **C**: Policy Set definition Ids or Names

It creates one exemption per Assignment assigning the Policy Set definition. It is useful for exempting multiple Policies in a Policy Set with one exemption. Specify the following:

- `policySetDefinitionId` for built-in Policy Set definitions in the form `"/providers/Microsoft.Authorization/policySetDefinitions/00000000-0000-0000-0000-000000000000"`.
- `policySetDefinitionName` for custom Policy Set definitions. In CSV files specify the cell in `assignmentReferenceId` as `"policySetDefinitions/{{policySetDefinitionName}}"`.
- Optionally, for Policy Set Assignments only, `policyDefinitionReferenceIds` containing an array of [strings as detailed below](#specifying-policydefinitionreferenceids).

In CSV files use the column `assignmentReferenceId`, and optionally `policyDefinitionReferenceIds`.

### Specifying `policyDefinitionReferenceIds`

`policyDefinitionReferenceIds` is used to exempt specific Policies within a Policy Set. It is only used explicitly with `policyAssignmentId` and `policySetDefinitionId` or `policySetDefinitionName`. For `policyDefinitionId` and `policyDefinitionName`, it is calculated by EPAC and should be empty.

`policyDefinitionReferenceIds` is an array of strings. Each string can be one of the following:

- `policyDefinitionReferenceId` as specified in the Policy Set definition.
- `policyDefinitionId` for built-in Policy definitions in the form `"/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000"`.
- `policyDefinitionName` for custom Policy definitions in the form `"policyDefinitions/{{policyDefinitionName}}"`.

In CSV files, `policyDefinitionReferenceIds` is a list of ampersand `&` separated strings. In JSON files, it is an array of strings.

## Defining the Scope with `scope` or `scopes`

The `scope` property is used to define a single scope. The `scopes` property is used to define multiple scopes. `scopes` was introduced in v10.1.0.

> [!TIP]
> Using a `scopes` array creates nicely concatenated values for `displayName` and `description` for single scope. We recommend to **always** use `scopes`. You can suppress the concatenation by adding a colon `:` at the beginning of each string before the scope.

### `scope` defines a single scope

It is unchanged from previous versions.

### `scopes` Defines multiple Scopes in a single Entry

 A list of Management Groups, subscriptions, Resource Groups or resource Ids. In CSV files it is a list separated by an ampersand `&`. In JSON files it is an array of strings.

 The last part of the scope is used as a postfix in the exemption `displayName` and `description` to make it easier to identify the scope. This behavior can be overridden by:
 
 - Adding a human readable name followed by a colon `:` before the scope: `humanReadableName:/subscriptions/11111111-2222-3333-4444-555555555555`.
 - Adding just a colon `:` before the scope to suppress the concatenation: `:/subscriptions/11111111-2222-3333-4444-555555555555`.

In CSV files, the `scope` column is still supported for backward compatibility. We recommend using the `scopes` column for all new exemptions. `scopes` is a list of ampersand `&` separated strings.

In JSON files, `scope` is a string and `scopes` is an array of strings.
 
## Combining Policy Definitions at multiple Scopes

When using **Option A** or **Option C**  and/or `scopes`, EPAC needs to generate concatenated values for `name`, `displayName`, and `description` to ensure uniqueness and readability.

- `name` is generated by concatenating the `name` with a dash `-` and the Assignment `name` (the last part of the `policyAssignmentId`).
- `displayName` and `description` are generated by concatenating the `displayName` and `description` with a a space dash space (` - `), the last part of the scope, or the human readable name before the colon `:` (if using `scopes`).

It is best to explain the details with examples. They are based on JSON files, but the same principles apply to CSV files.
 
### Example with `policyDefinition` and `scopes`

#### Definition file:

```json
  {
      "exemptions": [
          {
              "name": "short-name",
              "displayName": "Descriptive name displayed on portal",
              "description": "More details",
              "exemptionCategory": "Waiver",
              "scopes": [
                  "/subscriptions/11111111-2222-3333-4444-555555555555",
                  "/subscriptions/11111111-2222-3333-4444-555555555556/resourceGroups/resourceGroupName1",
              ],
              "policyDefinitionId": "/providers/microsoft.authorization/policyDefinitions/00000000-0000-0000-0000-000000000000",
          }
      ]
  }
```

#### Generated fields for each assignment with the Policy specified:

- `name` is the same for all the scopes: "short-name-assignmentName"
- `displayName`: "Descriptive name displayed on portal - 11111111-2222-3333-4444-555555555555 - assignmentName"
- `displayName`: "Descriptive name displayed on portal - resourceGroupName1 - assignmentName"
- `description`: "More details - 11111111-2222-3333-4444-555555555555 - assignmentName"
- `description`: "More details - resourceGroupName1 - assignmentName"


### Example with `policyDefinition`, `scopes` and a human readable name

#### Definition file:

```json
  {
      "exemptions": [
          {
              "name": "short-name",
              "displayName": "Descriptive name displayed on portal",
              "description": "More details",
              "exemptionCategory": "Waiver",
              "scopes": [
                  "humanReadableName:/subscriptions/11111111-2222-3333-4444-555555555555",
                  "/subscriptions/11111111-2222-3333-4444-555555555556/resourceGroups/resourceGroupName1",
              ],
              "policyDefinitionId": "/providers/microsoft.authorization/policyDefinitions/00000000-0000-0000-0000-000000000000",
          }
      ]
  }
```

#### Generated fields for each assignment with the Policy specified:

- `name` is the same for all the scopes: "short-name-assignmentName"
- `displayName`: "Descriptive name displayed on portal - humanReadableName - assignmentName - humanReadableName"
- `displayName`: "Descriptive name displayed on portal - resourceGroupName1 - assignmentName "
- `description`: "More details - humanReadableName - assignmentName"
- `description`: "More details - resourceGroupName1 - assignmentName"

### Example with `policyDefinition` and a single `scope`

#### Definition file:

```json
  {
      "exemptions": [
          {
              "name": "short-name",
              "displayName": "Descriptive name displayed on portal",
              "description": "More details",
              "exemptionCategory": "Waiver",
              "scope": "/subscriptions/11111111-2222-3333-4444-555555555555/resourceGroups/resourceGroupName1",
              "policyDefinitionId": "/providers/microsoft.authorization/policyDefinitions/00000000-0000-0000-0000-000000000000",
          }
      ]
  }
```

#### Generated fields for the assignment with the Policy specified:

- `name`: "short-name-assignmentName" 
- `displayName`: "Descriptive name displayed on portal - assignmentName"
- `description`: "More details - assignmentName"

### Example with `policyAssignmentId` and `scopes`

#### Definition file:

```json
  {
      "exemptions": [
          {
              "name": "short-name",
              "displayName": "Descriptive name displayed on portal",
              "description": "More details",
              "exemptionCategory": "Waiver",
              "scopes": [
                  "/subscriptions/11111111-2222-3333-4444-555555555555",
                  "/subscriptions/11111111-2222-3333-4444-555555555556/resourceGroups/resourceGroupName1",
              ],
              "policyAssignmentId": "/providers/Microsoft.Management/managementGroups/{{managementGroupId}}/providers/Microsoft.Authorization/policyAssignments/{{policyAssignmentName}}",
          }
      ]
  }
```

#### Generated fields for this assignment:

- `name`: "short-name"
- `displayName`: "Descriptive name displayed on portal - 11111111-2222-3333-4444-555555555555
- `displayName`: "Descriptive name displayed on portal - resourceGroupName1"
- `description`: "More details - 11111111-2222-3333-4444-555555555555"
- `description`: "More details - resourceGroupName1"

### Example with `policyAssignmentId`, `scopes` and a human readable name

#### Definition file:

```json
  {
      "exemptions": [
          {
              "name": "short-name",
              "displayName": "Descriptive name displayed on portal",
              "description": "More details",
              "exemptionCategory": "Waiver",
              "scopes": [
                  "humanReadableName:/subscriptions/11111111-2222-3333-4444-555555555555",
                  "/subscriptions/11111111-2222-3333-4444-555555555556/resourceGroups/resourceGroupName1",
              ],
              "policyAssignmentId": "/providers/Microsoft.Management/managementGroups/{{managementGroupId}}/providers/Microsoft.Authorization/policyAssignments/{{policyAssignmentName}}",
          }
      ]
  }
```

#### Generated fields for this assignment:

- `name`: "short-name"
- `displayName`: "Descriptive name displayed on portal - humanReadableName"
- `displayName`: "Descriptive name displayed on portal - resourceGroupName1"
- `description`: "More details - humanReadableName"
- `description`: "More details - resourceGroupName1"

### Example with `policyAssignmentId` and a single `scope`
 
#### Definition file:

```json
  {
      "exemptions": [
          {
              "name": "short-name",
              "displayName": "Descriptive name displayed on portal",
              "description": "More details",
              "exemptionCategory": "Waiver",
              "scope": "/subscriptions/11111111-2222-3333-4444-555555555555/resourceGroups/resourceGroupName1",
              "policyAssignmentId": "/providers/Microsoft.Management/managementGroups/{{managementGroupId}}/providers/Microsoft.Authorization/policyAssignments/{{policyAssignmentName}}",
          }
      ]
  }
```

#### Generated fields for this assignment:

- `name`: "short-name"
- `displayName`: "Descriptive name displayed on portal"
- `description`: "More details"

## CSV Format

The columns must have the headers as described below. The order of the columns is not important.

### Regular Columns

- `name` - unique name, we recommend a GUID.
- `displayName` - descriptive name displayed on portal.
- `exemptionCategory` - `Waiver` or `Mitigated`.
- `scope` - individual Management Group, subscription, Resource Group or resource.
- `scopes` - list of ampersand `&` separated Management Groups, subscriptions, Resource Groups or resource Ids. Ampersand is used instead of commas since it is not a valid character in a scope name and therefore doesn't conflict.
- Optional
  - `expiresOn` - empty or expiry date.
  - `policyDefinitionReferenceIds` - list of ampersand `&` separated [strings as defined above](#specifying-policydefinitionreferenceids).
  - `assignmentScopeValidation` - `Default` or `DoNotValidate`
  - `resourceSelectors` - valid JSON (see JSON format below)
  - `metadata` - valid JSON (see JSON format below)

> [!CAUTION]
> Breaking change: v10.1.0 replaced the usual comma in `policyDefinitionReferenceIds` with an ampersand `&` to avoid conflicts with the scope Ids. You must replace in-cell commas with ampersands.

### Option **A** columns: Policy definition Ids or Names

- Column `assignmentReferenceId` must be formatted:
  - For Built-in Policy definition: `/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000`
  - For Custom Policy definition: `policyDefinitions/{{policyDefinitionName}}`
- Column `policyDefinitionReferenceIds` must be empty

### Option **B** columns: Policy Assignment Id

- Column `assignmentReferenceId` must be a Policy Assignment Id:
  - `/providers/Microsoft.Management/managementGroups/{{managementGroupId}}/providers/Microsoft.Authorization/policyAssignments/{{policyAssignmentName}}`
- Column `policyDefinitionReferenceIds` must be an ampersand separated list containing any of the following:
  - Empty for Policy Assignment of a single Policy, or to exempt the scope from every Policy in the assigned Policy Set
  - One of the [options as detailed above](#specifying-policydefinitionreferenceids)

Legacy column `policyAssignmentId` is still supported for backward compatibility for **Option B** only.

### Option **C** columns: Policy Set definition Ids or Names

- Column `assignmentReferenceId` must be a Policy Set definition Id or Name
  - Built-in Policy Set definition: `/providers/Microsoft.Authorization/policySetDefinitions/00000000-0000-0000-0000-000000000000`
  - Custom Policy Set definition: `policySetDefinitions/{{policySetDefinitionName}}`
- Column `policyDefinitionReferenceIds` must be an ampersand separated list containing any of the following:
  - Empty to exempt all Policies in the Policy Set
  - One of the [options as detailed above](#specifying-policydefinitionreferenceids)

## Moving from Excluded Scopes to Exemptions

If you are moving from using excluded scopes to the use of exemptions the by default EPAC will not deploy new exemptions that are part of an assignment excluded scopes. As well as this - EPAC will delete any exemption if finds that is deployed to an excluded scope.

You can override this behavior by using the switch ```-SkipNotScopedExemptions``` when you call ```Build-DeploymentPlans```.
