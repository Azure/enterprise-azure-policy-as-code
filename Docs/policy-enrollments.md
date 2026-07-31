# Policy Enrollments

> [!WARNING]
> Policy Enrollments are an Azure preview feature. The resource contract and behavior may change before general availability. EPAC uses API version `2026-01-01-preview` for Policy Enrollments and for Policy Assignments whose `enforcementMode` is `Enroll`.

A Policy Enrollment enrolls a scope in a Policy Assignment whose `enforcementMode` is `Enroll`. See the [Microsoft.Authorization/policyEnrollments resource reference](https://learn.microsoft.com/azure/templates/microsoft.authorization/policyenrollments) for the Azure resource contract.

## Assignment

The referenced Policy Assignment must use the `Enroll` enforcement mode:

```json
"enforcementMode": "Enroll"
```

EPAC also supports the existing `Default` and `DoNotEnforce` values.

## Enrollment File

Create JSON or JSONC files under `policyEnrollments`. Each file can define one scope with `scope`, or expand the same enrollment across multiple scopes with `scopes`:

```json
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-enrollment-schema.json",
    "name": "application-team-enrollment",
    "scopes": [
        "/subscriptions/11111111-2222-3333-4444-555555555555",
        "/subscriptions/66666666-7777-8888-9999-000000000000"
    ],
    "displayName": "Application team enrollment",
    "description": "Enroll the subscription in the assigned policy set.",
    "policyAssignmentId": "/providers/Microsoft.Management/managementGroups/contoso/providers/Microsoft.Authorization/policyAssignments/enrollable-baseline",
    "assignmentScopeValidation": "Default",
    "policyDefinitionReferenceIds": [
        "allowed-locations"
    ],
    "resourceSelectors": [
        {
            "name": "locations",
            "selectors": [
                {
                    "kind": "resourceLocation",
                    "in": [
                        "eastus",
                        "westus"
                    ]
                }
            ]
        }
    ],
    "metadata": {
        "owner": "application-team"
    }
}
```

`name` and `policyAssignmentId` are required. Define exactly one of `scope` or `scopes`; `scopes` must be a non-empty array of unique scope strings. `assignmentScopeValidation` defaults to `Default` and also supports `DoNotValidate`. All other fields shown above are optional.

EPAC expands `scopes` into one Azure Policy Enrollment per scope. Each resource has its own ID:

```text
<scope>/providers/Microsoft.Authorization/policyEnrollments/<name>
```

## Folder And Desired State

The folder applies to the selected EPAC environment through the scopes and assignments referenced by each file:

```text
Definitions/
  policyEnrollments/
    application-team-enrollment.jsonc
```

If `policyEnrollments` is absent, EPAC does not retrieve, plan, deploy, or delete Policy Enrollments. Creating the folder opts the EPAC environment into managing them. An empty folder represents an empty desired state and may cause existing enrollments to be deleted according to the environment's `desiredState.strategy`.

During plan creation EPAC retrieves current resources from Azure Resource Graph with:

```kusto
policyresources
| where type =~ "microsoft.authorization/policyenrollments"
```

EPAC compares `displayName`, `description`, `policyAssignmentId`, `assignmentScopeValidation`, `policyDefinitionReferenceIds`, `resourceSelectors`, and `metadata`. Changes produce an update in the Policy deployment plan.

## Ownership

EPAC adds `metadata.pacOwnerId` to every managed Policy Enrollment. Do not define `pacOwnerId` in an enrollment file because it is reserved for EPAC.

With the `ownedOnly` desired-state strategy, EPAC deletes only enrollments carrying the current environment's `pacOwnerId`. With `full`, EPAC may also delete unowned enrollments in managed scopes, but it does not delete resources owned by another EPAC instance.