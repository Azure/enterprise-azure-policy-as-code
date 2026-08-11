BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'
    $script:Tag = 'platform/amba/2026.06.1'

    function New-ParameterFileTestEnvironment {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Root
        )

        $definitionsRoot = Join-Path $Root 'Definitions'
        $libraryRoot = Join-Path $Root 'library'

        foreach ($path in @(
                $definitionsRoot
                (Join-Path $definitionsRoot 'policyStructures')
                (Join-Path $definitionsRoot 'policyAssignments')
                (Join-Path $libraryRoot 'platform/amba/archetype_definitions')
                (Join-Path $libraryRoot 'platform/amba/policy_assignments')
                (Join-Path $libraryRoot 'platform/amba/policy_definitions')
                (Join-Path $libraryRoot 'platform/amba/policy_set_definitions')
            )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $definitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

        Set-Content -Path (Join-Path $definitionsRoot 'policyStructures/amba.policy_default_structure.epac-dev.jsonc') -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "alz": {
      "management_group_function": "Intermediate Root",
      "value": "/providers/Microsoft.Management/managementGroups/alz"
    }
  },
  "defaultParameterValues": {
    "changed_parameter": [
      {
        "policy_assignment_name": "Deploy-Test",
        "parameters": {
          "parameter_name": "ChangedParameter",
          "value": "structure-default"
        }
      }
    ]
  },
  "overrides": {
    "archetypes": {
      "ignore": [],
      "custom": [
        {
          "name": "alz",
          "type": "existing",
          "policy_assignments_to_add": [
            {
              "policy_name": "Deploy-Test",
              "assignment_name": "Deploy-Test-Short"
            }
          ]
        }
      ]
    },
    "parameters": {
      "root": [
        {
          "policy_assignment_name": "Deploy-Test",
          "parameters": [
            {
              "parameter_name": "ChangedParameter",
              "value": "structure-override"
            }
          ]
        }
      ]
    },
    "enforcementMode": {}
  }
}
'@

        Set-Content -Path (Join-Path $definitionsRoot 'policyStructures/amba.policy_set_parameters.jsonc') -Value @'
{
  "Test-Policy-Set": {
    "ArrayParameter": [
      "one",
      "two"
    ],
    "ChangedParameter": "custom",
    "NoDefaultParameter": "provided",
    "ObjectParameter": {
      "second": 2,
      "first": 1
    },
    "SameParameter": "default"
  }
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/amba/archetype_definitions/root.alz_archetype_definition.json') -Value @'
{
  "name": "root",
  "policy_assignments": [
    "Deploy-Test"
  ]
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/amba/policy_assignments/Deploy-Test.alz_policy_assignment.json') -Value @'
{
  "name": "Deploy-Test",
  "properties": {
    "description": "Test assignment",
    "displayName": "Test assignment",
    "policyDefinitionId": "/providers/Microsoft.Management/managementGroups/placeholder/providers/Microsoft.Authorization/policySetDefinitions/Test-Policy-Set",
    "parameters": {
      "ChangedParameter": {
        "value": "library-assignment"
      },
      "LibraryOnlyParameter": {
        "value": "library-only"
      },
      "SameParameter": {
        "value": "library-assignment"
      }
    }
  }
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/amba/policy_set_definitions/Test-Policy-Set.alz_policy_set_definition.json') -Value @'
{
  "name": "Test-Policy-Set",
  "properties": {
    "parameters": {
      "ArrayParameter": {
        "defaultValue": [
          "one",
          "two"
        ],
        "type": "Array"
      },
      "ChangedParameter": {
        "defaultValue": "default",
        "type": "String"
      },
      "NoDefaultParameter": {
        "type": "String"
      },
      "ObjectParameter": {
        "defaultValue": {
          "first": 1,
          "second": 2
        },
        "type": "Object"
      },
      "SameParameter": {
        "defaultValue": "default",
        "type": "String"
      }
    }
  }
}
'@

        [pscustomobject]@{
            DefinitionsRoot = $definitionsRoot
            LibraryRoot     = $libraryRoot
            ParameterFile   = Join-Path $definitionsRoot 'policyStructures/amba.policy_set_parameters.jsonc'
        }
    }

    function Invoke-ParameterFileSync {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Root,

            [Parameter(Mandatory = $true)]
            [pscustomobject] $Environment,

            [switch] $EnableOverrides
        )

        $helperScriptPath = Join-Path $Root 'run-sync.ps1'
        $overrideSwitch = if ($EnableOverrides) { ' -EnableOverrides' } else { '' }
        Set-Content -Path $helperScriptPath -Value @"
function Invoke-RestMethod {
    [pscustomobject]@{ ref = @('refs/tags/$($script:Tag)') }
}

& '$($script:SyncScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($Environment.DefinitionsRoot.Replace("'", "''"))' -LibraryPath '$($Environment.LibraryRoot.Replace("'", "''"))' -Type AMBA -PacEnvironmentSelector 'epac-dev' -Tag '$($script:Tag)' -SyncAssignmentsOnly -ParameterFile '$($Environment.ParameterFile.Replace("'", "''"))'$overrideSwitch
"@

        & pwsh -NoLogo -NoProfile -File $helperScriptPath | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Sync-ALZPolicyFromLibrary parameter file input' {
    It 'emits only parameter values that differ from policy set defaults without overrides enabled' {
        $root = Join-Path $TestDrive 'WithoutOverrides'
        $environment = New-ParameterFileTestEnvironment -Root $root

        Invoke-ParameterFileSync -Root $root -Environment $environment

        $assignmentFile = Join-Path $environment.DefinitionsRoot 'policyAssignments/AMBA/epac-dev/Intermediate Root/Deploy-Test.jsonc'
        $assignment = Get-Content -Path $assignmentFile -Raw | ConvertFrom-Json
        @($assignment.parameters.PSObject.Properties.Name) | Should -Be @('ChangedParameter', 'NoDefaultParameter')
        $assignment.parameters.ChangedParameter | Should -Be 'custom'
        $assignment.parameters.NoDefaultParameter | Should -Be 'provided'
    }

    It 'ignores parameter overrides while still applying archetype overrides' {
        $root = Join-Path $TestDrive 'WithOverrides'
        $environment = New-ParameterFileTestEnvironment -Root $root

        Invoke-ParameterFileSync -Root $root -Environment $environment -EnableOverrides

        $assignmentFile = Join-Path $environment.DefinitionsRoot 'policyAssignments/AMBA/epac-dev/Intermediate Root/Deploy-Test-Short.jsonc'
        Test-Path $assignmentFile | Should -BeTrue

        $assignment = Get-Content -Path $assignmentFile -Raw | ConvertFrom-Json
        @($assignment.parameters.PSObject.Properties.Name) | Should -Be @('ChangedParameter', 'NoDefaultParameter')
        $assignment.parameters.ChangedParameter | Should -Be 'custom'
    }

    It 'rejects parameter files for non-AMBA library types' {
        $root = Join-Path $TestDrive 'UnsupportedType'
        $environment = New-ParameterFileTestEnvironment -Root $root
        $helperScriptPath = Join-Path $root 'run-unsupported-sync.ps1'

        Set-Content -Path $helperScriptPath -Value @"
function Invoke-RestMethod {
    [pscustomobject]@{ ref = @('refs/tags/$($script:Tag)') }
}

& '$($script:SyncScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($environment.DefinitionsRoot.Replace("'", "''"))' -LibraryPath '$($environment.LibraryRoot.Replace("'", "''"))' -Type ALZ -PacEnvironmentSelector 'epac-dev' -Tag '$($script:Tag)' -SyncAssignmentsOnly -ParameterFile '$($environment.ParameterFile.Replace("'", "''"))'
"@

        $output = & pwsh -NoLogo -NoProfile -File $helperScriptPath 2>&1 | Out-String

        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match '\-ParameterFile is only supported when \-Type is AMBA\.'
    }
}
