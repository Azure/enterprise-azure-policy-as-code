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

    It 'uses assignment_name when the archetype is renamed mid-pipeline (alz -> root)' {
        $definitionsRoot = Join-Path $TestDrive 'DefinitionsRename'
        $libraryRoot = Join-Path $TestDrive 'libraryRename'
        $helperScriptPath = Join-Path $TestDrive 'run-sync-rename.ps1'
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
    "alz": {
      "management_group_function": "Intermediate Root",
      "value": "/providers/Microsoft.Management/managementGroups/alz"
    }
  },
  "defaultParameterValues": {},
  "overrides": {
    "archetypes": {
      "ignore": [],
      "custom": [
        {
          "name": "alz",
          "type": "existing",
          "policy_assignments_to_add": [
            {
              "policy_name": "Audit-MachineLearning-PrivateEndpointId",
              "assignment_name": "Audit-ML-Root"
            }
          ]
        }
      ]
    },
    "parameters": {},
    "enforcementMode": {}
  }
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/archetype_definitions/alz.alz_archetype_definition.json') -Value @'
{
  "name": "alz",
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

        $assignmentFile = Join-Path $definitionsRoot 'policyAssignments/ALZ/epac-dev/Intermediate Root/Audit-ML-Root.jsonc'
        Test-Path $assignmentFile | Should -BeTrue

        $assignmentContent = Get-Content -Path $assignmentFile -Raw | ConvertFrom-Json
        $assignmentContent.assignment.name | Should -Be 'Audit-ML-Root'
        $assignmentContent.nodeName | Should -Be 'root/Audit-ML-Root'

        # The override must resolve, so the long library name file must not be created and no warning emitted.
        (Test-Path (Join-Path $definitionsRoot 'policyAssignments/ALZ/epac-dev/Intermediate Root/Audit-MachineLearning-PrivateEndpointId.jsonc')) | Should -BeFalse
        $output | Should -Not -Match 'did not resolve to any created assignment'
    }

    It 'inherits parent policies when based_on uses the pre-rename archetype name (based_on alz)' {
        $definitionsRoot = Join-Path $TestDrive 'DefinitionsBasedOn'
        $libraryRoot = Join-Path $TestDrive 'libraryBasedOn'
        $helperScriptPath = Join-Path $TestDrive 'run-sync-basedon.ps1'
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
    "alz": {
      "management_group_function": "Intermediate Root",
      "value": "/providers/Microsoft.Management/managementGroups/alz"
    },
    "test": {
      "management_group_function": "Test",
      "value": "/providers/Microsoft.Management/managementGroups/test"
    }
  },
  "defaultParameterValues": {},
  "overrides": {
    "archetypes": {
      "ignore": [],
      "custom": [
        {
          "name": "alz",
          "type": "existing",
          "policy_assignments_to_add": [
            {
              "policy_name": "Append-Redis-sslEnforcement",
              "assignment_name": "apss"
            }
          ]
        },
        {
          "name": "test",
          "based_on": "alz",
          "type": "existing",
          "policy_assignments_to_add": [
            "Deny-Redis-http"
          ]
        }
      ]
    },
    "parameters": {},
    "enforcementMode": {}
  }
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/archetype_definitions/root.alz_archetype_definition.json') -Value @'
{
  "name": "root",
  "policy_assignments": [
    "Audit-AppGW-WAF",
    "Deny-Redis-http",
    "Append-Redis-sslEnforcement"
  ]
}
'@

        foreach ($policyName in @('Audit-AppGW-WAF', 'Deny-Redis-http', 'Append-Redis-sslEnforcement')) {
            Set-Content -Path (Join-Path $libraryRoot "platform/alz/policy_assignments/$policyName.alz_policy_assignment.json") -Value @"
{
  "type": "Microsoft.Authorization/policyAssignments",
  "apiVersion": "2022-06-01",
  "name": "$policyName",
  "properties": {
    "description": "Test policy",
    "displayName": "$policyName",
    "policyDefinitionId": "/providers/Microsoft.Management/managementGroups/placeholder/providers/Microsoft.Authorization/policyDefinitions/$policyName",
    "enforcementMode": "Default",
    "scope": "/providers/Microsoft.Management/managementGroups/placeholder",
    "notScopes": [],
    "parameters": {}
  }
}
"@
        }

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

        # The "test" archetype is based_on the pre-rename name "alz". It must inherit every parent
        # (root) policy assignment, not only its own policy_assignments_to_add entry.
        $testScope = Join-Path $definitionsRoot 'policyAssignments/ALZ/epac-dev/Test'
        Test-Path (Join-Path $testScope 'Audit-AppGW-WAF.jsonc') | Should -BeTrue
        Test-Path (Join-Path $testScope 'Deny-Redis-http.jsonc') | Should -BeTrue
        Test-Path (Join-Path $testScope 'Append-Redis-sslEnforcement.jsonc') | Should -BeTrue

        $testAssignment = Get-Content -Path (Join-Path $testScope 'Audit-AppGW-WAF.jsonc') -Raw | ConvertFrom-Json
        $testAssignment.nodeName | Should -Be 'test/Audit-AppGW-WAF'
    }
}
