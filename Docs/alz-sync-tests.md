# ALZ sync test coverage

This document describes the ALZ-focused tests in `Tests\CloudAdoptionFramework` and what each one verifies.

## Test entry point

Run the full suite with:

```powershell
Invoke-Pester -Path 'Tests\CloudAdoptionFramework'
```

## Smoke coverage

These tests exercise the real regression harness in `Scripts\CloudAdoptionFramework\Test-ALZSyncRegression.ps1`. They run against local deterministic fixtures and include ALZ as part of the end-to-end flow.

### `Smoke\Test-ALZSyncRegression.Tests.ps1`

#### `passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries`

Verifies that the regression harness can:

- generate the ALZ policy structure
- sync ALZ assignments from the fixture library
- validate the generated ALZ structure and scopes
- complete without throwing

For ALZ, this is the broadest smoke test because it covers the normal `New-ALZPolicyDefaultStructure` + `Sync-ALZPolicyFromLibrary` + regression validation flow together.

#### `supports baseline comparison against previously generated output`

Verifies that ALZ output is stable across repeat runs by:

- generating a baseline ALZ output set
- generating a second ALZ output set in a clean Definitions root
- comparing the new ALZ structure and assignment output against the baseline
- confirming the regression harness accepts the match

#### `fails when the generated output no longer matches the baseline`

Verifies that ALZ regressions are caught by:

- generating an ALZ baseline
- intentionally changing the saved ALZ structure output
- re-running the regression harness
- confirming it fails when ALZ output no longer matches the baseline

## Unit coverage for `New-ALZPolicyDefaultStructure`

These tests validate deterministic ALZ structure generation behavior directly.

### `Unit\New-ALZPolicyDefaultStructure.Tests.ps1`

#### `creates ALZ structure output with selector suffix and ALZ-only defaults`

Verifies that ALZ structure generation:

- writes `policyStructures\alz.policy_default_structure.epac-dev.jsonc`
- includes the expected ALZ management group mapping for `alz`
- includes expected ALZ default parameter values such as:
  - `base_effect`
  - `ama_mdfc_sql_workspace_id`
- does **not** add `archetypeScopeMappings`, which should remain SLZ-only

#### `supports tag-based generation when tag lookup and git clone are mocked`

Verifies that ALZ generation still works when using `-Tag` by mocking the external dependencies:

- mocks tag discovery
- mocks cloning of the Azure Landing Zones Library
- runs `New-ALZPolicyDefaultStructure.ps1` with an ALZ tag
- confirms the ALZ structure file is created successfully

This protects the ALZ tagged-release flow without depending on live GitHub access.

## Unit coverage for `Sync-ALZPolicyFromLibrary`

These tests validate ALZ sync behavior directly against deterministic ALZ fixture content.

### `Unit\Sync-ALZPolicyFromLibrary.Tests.ps1`

#### `creates ALZ definitions and assignments from fixture content`

Verifies that a normal ALZ sync:

- creates ALZ policy definition files
- creates ALZ policy set definition files
- creates ALZ assignment files in the expected folder layout
- preserves expected assignment metadata such as:
  - additional role assignment scope
  - `nodeName`
  - fallback `definitionEntry` behavior for policy definitions

#### `supports SyncAssignmentsOnly without creating policy definition files`

Verifies that `-SyncAssignmentsOnly` for ALZ:

- still creates ALZ assignment files
- skips ALZ policy definition generation
- skips ALZ policy set definition generation

This confirms the partial-sync path behaves correctly for assignment-only updates.

#### `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode`

Verifies that ALZ override support works correctly when `-EnableOverrides` is used:

- ignored archetypes are excluded
- custom archetypes based on existing or new management groups are created
- assignments are added or removed based on override settings
- parameter overrides are written into the generated ALZ assignment
- `enforcementMode` overrides are applied to the expected assignments

This is the main ALZ customization test.

#### `includes guardrail assignments only when requested`

Verifies that ALZ guardrail assignment behavior is opt-in:

- guardrail assignments are not created by default
- guardrail assignments are created when `-CreateGuardrailAssignments` is specified

#### `removes obsolete assignments after a subsequent sync`

Verifies that ALZ resync cleanup works:

- the first sync creates an ALZ assignment
- a second sync uses updated ALZ library content where that assignment no longer exists
- the obsolete ALZ assignment file is removed from the Definitions tree

This protects against stale generated output after library changes.

#### `fails with guidance when the policy structure file is missing`

Verifies that ALZ sync fails clearly when the required ALZ structure file has not been generated first:

- runs `Sync-ALZPolicyFromLibrary.ps1` without a structure file
- confirms the output tells the user to run `New-ALZPolicyDefaultStructure.ps1` first

This protects the main ALZ prerequisite/error path.

## What is not ALZ-specific

The following tests are part of the same suite but focus on AMBA or SLZ behavior rather than ALZ:

- AMBA structure generation
- SLZ structure generation and scope mapping
- AMBA extended policy sync
- SLZ composite scope resolution

Those are documented by the test names in the suite, but this file is intentionally limited to ALZ coverage.

## Mapping to the original integration guide

This section maps the non-v10 sections in `Docs\integrating-with-alz-library.md` to the ALZ tests that apply to them.

| Original doc section | ALZ tests that apply | Notes |
| --- | --- | --- |
| `## Breaking changes and migration notes` | `supports baseline comparison against previously generated output`; `fails when the generated output no longer matches the baseline`; `removes obsolete assignments after a subsequent sync` | Covers regression detection and artifact drift after library changes. |
| `### Recommended upgrade workflow` | `passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries`; `supports baseline comparison against previously generated output`; `fails when the generated output no longer matches the baseline` | Exercises the isolated generate/sync/compare workflow recommended in the guide. |
| `## Pre-requisites` | No direct automated ALZ test | This section describes required Azure resources and deployment prerequisites rather than script behavior. |
| `## Using the new Azure Landing Zone Library sync process` | All ALZ tests in this document | This is the main umbrella section for the generate + sync workflow that the ALZ suite targets. |
| `### Create a policy default structure file` | `creates ALZ structure output with selector suffix and ALZ-only defaults`; `supports tag-based generation when tag lookup and git clone are mocked`; `fails when the policy structure file is missing` | Covers structure generation, selector-specific naming, default values, tag-driven generation, and the prerequisite relationship to sync. |
| `### Sync with ALZ Policy Repo` | `creates ALZ definitions and assignments from fixture content`; `supports SyncAssignmentsOnly without creating policy definition files`; `removes obsolete assignments after a subsequent sync`; `fails with guidance when the policy structure file is missing`; `passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries` | Covers normal sync, assignment-only sync, cleanup after library changes, missing-structure guidance, and broad end-to-end execution. |
| `## Examples` | `passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries`; `creates ALZ structure output with selector suffix and ALZ-only defaults`; `creates ALZ definitions and assignments from fixture content` | The examples are covered by the same create-then-sync flow exercised in unit and smoke tests. |
| `### ALZ` | `creates ALZ structure output with selector suffix and ALZ-only defaults`; `creates ALZ definitions and assignments from fixture content`; `passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries` | Direct coverage of the example ALZ commands. |
| `## Advanced Scenarios` | `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode`; `includes guardrail assignments only when requested`; `supports SyncAssignmentsOnly without creating policy definition files` | The ALZ advanced-scenario coverage is mostly concentrated in the override and guardrail tests. |
| `### Maintaining multiple ALZ/AMBA environments` | `creates ALZ structure output with selector suffix and ALZ-only defaults`; `creates ALZ definitions and assignments from fixture content` | Validates selector-specific structure naming and selector-scoped assignment output. |
| `### Custom management group structure (Requires EPAC v11)` | `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | Covered through custom archetype and custom management group mapping scenarios. |
| `### Customize an existing archetype (Requires EPAC v11)` | `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | Covered through assignment add/remove behavior on existing archetypes. |
| `### Create a new archetype based on an existing archetype (Requires EPAC v11)` | `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | Covered through the custom archetype override scenarios. |
| `### Ignore an archetype (Requires EPAC v11)` | `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | Covered by the override path that excludes selected archetypes. |
| `### Modify a parameter for a specific archetype (Requires EPAC v11)` | `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | Covered by the override path that changes assignment parameter values. |
| `### Modify the enforcement mode for an assignment (Requires EPAC v11)` | `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | Covered by the override path that sets `DoNotEnforce` on targeted assignments. |
| `### Assign an archetype to multiple management groups (Requires EPAC v11)` | Partial coverage via `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | The ALZ suite covers custom archetype/mapping behavior, but not every possible multi-scope ALZ permutation. |
| `### Disabling / Changing specific parameters` | `creates ALZ structure output with selector suffix and ALZ-only defaults`; `applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode` | Covers both default-parameter extraction and parameter override application. |
| `### Deploying Workload Specific Compliance Guardrails (Requires EPAC v11)` | `includes guardrail assignments only when requested` | Direct guardrail coverage. |
| `### Using EPAC to manage ALZ policies in place of Terraform` | `passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries`; `creates ALZ definitions and assignments from fixture content` | Indirectly covered because the tests validate generated EPAC artifacts, not Terraform interoperability itself. |
| `## Regression testing harness` | `passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries`; `supports baseline comparison against previously generated output`; `fails when the generated output no longer matches the baseline` | Direct coverage of the regression harness behavior. |

## Out-of-scope original guide sections

Per the original request, the EPAC v10-oriented sections are intentionally not mapped to ALZ tests here:

- `### Using a custom library for custom management group structures (Required EPAC v10 - migrate to the new process above)`
- `### Migrating from the legacy sync process to the new sync process`
- `### *Cloud Adoption Framework Aligned*`
- `### *Cloud Adoption Framework Unaligned*`
