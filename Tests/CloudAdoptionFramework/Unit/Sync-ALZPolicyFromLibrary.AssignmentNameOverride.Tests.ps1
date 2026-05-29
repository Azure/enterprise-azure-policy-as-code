BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'
}

Describe 'Sync-ALZPolicyFromLibrary assignment name overrides' {
    It 'uses assignment_name when policy_assignments_to_add entry is an object' {
        $definitionsRoot = Join-Path $TestDrive 'DefinitionsSuccess'
        $libraryRoot = Join-Path $TestDrive 'librarySuccess'
        $helperScriptPath = Join-Path $TestDrive 'run-sync-success.ps1'
        $tag = 'platform/alz/2026.04.2'

        foreach ($path in @(
                $definitionsRoot
                (Join-Path $definitionsRoot 'policyStructures')
                (Join-Path $definitionsRoot 'policyAssignments')
                (Join-Path $libraryRoot 'platform/alz/archetype_definitions')
                (Join-Path $libraryRoot 'platform/alz/policy_assignments')
                (Join-Path $libraryRoot 'platform/alz/policy_definitions')
            )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $definitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

        Set-Content -Path (Join-Path $definitionsRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc') -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "landingzones": {
      "management_group_function": "Landing Zones",
      "value": "/providers/Microsoft.Management/managementGroups/landingzones"
    }
  },
  "defaultParameterValues": {},
  "overrides": {
    "archetypes": {
      "ignore": [],
      "custom": [
        {
          "name": "landingzones",
          "type": "existing",
          "policy_assignments_to_add": [
            {
              "policy_name": "Audit-MachineLearning-PrivateEndpointId",
              "assignment_name": "Audit-ML-PEndpointId"
            }
          ]
        }
      ]
    },
    "parameters": {},
    "enforcementMode": {
      "DoNotEnforce": [
        "landing_zones/Audit-ML-PEndpointId"
      ]
    }
  }
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/archetype_definitions/landingzones.alz_archetype_definition.json') -Value @'
{
  "name": "landingzones",
  "policy_assignments": []
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/policy_definitions/Audit-MachineLearning-PrivateEndpointId.alz_policy_definition.json') -Value @'
{
  "name": "Audit-MachineLearning-PrivateEndpointId",
  "properties": {
    "displayName": "Audit Machine Learning Private Endpoint Id",
    "description": "Test policy",
    "parameters": {},
    "policyRule": {
      "if": {
        "field": "type",
        "equals": "Microsoft.MachineLearningServices/workspaces"
      },
      "then": {
        "effect": "audit"
      }
    }
  }
}
'@

        Set-Content -Path $helperScriptPath -Value @"
function Invoke-RestMethod {
    param(
        [string] `$Uri
    )

    [pscustomobject]@{
        ref = @('refs/tags/$tag')
    }
}

& '$($script:SyncScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($definitionsRoot.Replace("'", "''"))' -LibraryPath '$($libraryRoot.Replace("'", "''"))' -Type ALZ -PacEnvironmentSelector 'epac-dev' -Tag '$tag' -EnableOverrides -SyncAssignmentsOnly
"@

        & pwsh -NoLogo -NoProfile -File $helperScriptPath | Out-Null

        $assignmentFile = Join-Path $definitionsRoot 'policyAssignments/ALZ/epac-dev/Landing Zones/Audit-ML-PEndpointId.jsonc'
        Test-Path $assignmentFile | Should -BeTrue

        $assignmentContent = Get-Content -Path $assignmentFile -Raw | ConvertFrom-Json
        $assignmentContent.assignment.name | Should -Be 'Audit-ML-PEndpointId'
        $assignmentContent.definitionEntry.policyName | Should -Be 'Audit-MachineLearning-PrivateEndpointId'
        $assignmentContent.enforcementMode | Should -Be 'DoNotEnforce'
    }

    It 'fails with a clear message when a long string entry is added without assignment_name' {
        $definitionsRoot = Join-Path $TestDrive 'DefinitionsFailure'
        $libraryRoot = Join-Path $TestDrive 'libraryFailure'
        $helperScriptPath = Join-Path $TestDrive 'run-sync.ps1'
        $tag = 'platform/alz/2026.04.2'

        foreach ($path in @(
                $definitionsRoot
                (Join-Path $definitionsRoot 'policyStructures')
                (Join-Path $definitionsRoot 'policyAssignments')
                (Join-Path $libraryRoot 'platform/alz/archetype_definitions')
                (Join-Path $libraryRoot 'platform/alz/policy_assignments')
                (Join-Path $libraryRoot 'platform/alz/policy_definitions')
            )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $definitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

        Set-Content -Path (Join-Path $definitionsRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc') -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "landingzones": {
      "management_group_function": "Landing Zones",
      "value": "/providers/Microsoft.Management/managementGroups/landingzones"
    }
  },
  "defaultParameterValues": {},
  "overrides": {
    "archetypes": {
      "ignore": [],
      "custom": [
        {
          "name": "landingzones",
          "type": "existing",
          "policy_assignments_to_add": [
            "Audit-MachineLearning-PrivateEndpointId"
          ]
        }
      ]
    },
    "parameters": {},
    "enforcementMode": {}
  }
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/archetype_definitions/landingzones.alz_archetype_definition.json') -Value @'
{
  "name": "landingzones",
  "policy_assignments": []
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/policy_definitions/Audit-MachineLearning-PrivateEndpointId.alz_policy_definition.json') -Value @'
{
  "name": "Audit-MachineLearning-PrivateEndpointId",
  "properties": {
    "displayName": "Audit Machine Learning Private Endpoint Id",
    "description": "Test policy",
    "parameters": {},
    "policyRule": {
      "if": {
        "field": "type",
        "equals": "Microsoft.MachineLearningServices/workspaces"
      },
      "then": {
        "effect": "audit"
      }
    }
  }
}
'@

        Set-Content -Path $helperScriptPath -Value @"
function Invoke-RestMethod {
    param(
        [string] `$Uri
    )

    [pscustomobject]@{
        ref = @('refs/tags/$tag')
    }
}

& '$($script:SyncScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($definitionsRoot.Replace("'", "''"))' -LibraryPath '$($libraryRoot.Replace("'", "''"))' -Type ALZ -PacEnvironmentSelector 'epac-dev' -Tag '$tag' -EnableOverrides -SyncAssignmentsOnly
"@

        $output = & pwsh -NoLogo -NoProfile -File $helperScriptPath 2>&1 | Out-String

        $output | Should -Match "would generate an assignment name of 39 chars"
        $output | Should -Match "24-char limit"
        (Test-Path (Join-Path $definitionsRoot 'policyAssignments/ALZ/epac-dev/Landing Zones/Audit-MachineLearning-PrivateEndpointId.jsonc')) | Should -BeFalse
    }
}
