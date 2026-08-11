BeforeAll {
    $script:NewStructureScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/New-ALZPolicyDefaultStructure.ps1'
    $script:DefinitionsRoot = Join-Path $TestDrive 'Definitions'
    $script:LibraryRoot = Join-Path $TestDrive 'library'

    function Invoke-RestMethod {
        [pscustomobject]@{
            ref = @('refs/tags/platform/amba/2026.06.1')
        }
    }

    foreach ($path in @(
            $script:DefinitionsRoot
            (Join-Path $script:LibraryRoot 'platform/amba/architecture_definitions')
            (Join-Path $script:LibraryRoot 'platform/amba/policy_set_definitions')
        )) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    Set-Content -Path (Join-Path $script:LibraryRoot 'platform/amba/architecture_definitions/amba.alz_architecture_definition.json') -Value @'
{
  "management_groups": []
}
'@

    Set-Content -Path (Join-Path $script:LibraryRoot 'platform/amba/alz_policy_default_values.json') -Value @'
{
  "defaults": []
}
'@

    Set-Content -Path (Join-Path $script:LibraryRoot 'platform/amba/policy_set_definitions/Alerting-Test.alz_policy_set_definition.json') -Value @'
{
  "name": "Alerting-Test",
  "properties": {
    "parameters": {
      "AlertSeverity": {
        "allowedValues": [
          0,
          1,
          2
        ],
        "defaultValue": 2,
        "type": "Integer"
      },
      "AlertEnabled": {
        "defaultValue": true,
        "type": "Boolean"
      },
      "ResourceTypes": {
        "defaultValue": [
          "Microsoft.Compute/virtualMachines"
        ],
        "type": "Array"
      },
      "RequiredValue": {
        "type": "String"
      }
    }
  }
}
'@

    Set-Content -Path (Join-Path $script:LibraryRoot 'platform/amba/policy_set_definitions/00-Zeta.alz_policy_set_definition.json') -Value @'
{
  "name": "Zeta-Policy-Set",
  "properties": {
    "parameters": {}
  }
}
'@
}

AfterAll {
    Remove-Item function:Invoke-RestMethod -ErrorAction SilentlyContinue
}

Describe 'New-ALZPolicyDefaultStructure parameter file generation' {
    It 'writes policy set parameter defaults and allowed value comments to JSONC' {
        & $script:NewStructureScriptPath `
            -DefinitionsRootFolder $script:DefinitionsRoot `
            -LibraryPath $script:LibraryRoot `
            -Type AMBA `
            -PacEnvironmentSelector 'epac-dev' `
            -GenerateParameterFile

        $parameterFile = Join-Path $script:DefinitionsRoot 'policyStructures/amba.policy_set_parameters.jsonc'
        Test-Path $parameterFile | Should -BeTrue

        $rawContent = Get-Content -Path $parameterFile -Raw
        $rawContent | Should -Match '// allowedValues: \[0,1,2\]\r?\n    "AlertSeverity": 2'
        $rawContent | Should -Match '"AlertEnabled": true,\r?\n    // allowedValues: \[0,1,2\]'
        $rawContent.IndexOf('"Alerting-Test"') | Should -BeLessThan $rawContent.IndexOf('"Zeta-Policy-Set"')

        $parameters = $rawContent | ConvertFrom-Json
        $parameters.'Alerting-Test'.AlertSeverity | Should -Be 2
        $parameters.'Alerting-Test'.AlertEnabled | Should -BeTrue
        $parameters.'Alerting-Test'.ResourceTypes | Should -Be @('Microsoft.Compute/virtualMachines')
        $parameters.'Alerting-Test'.PSObject.Properties['RequiredValue'].Value | Should -BeNullOrEmpty
    }

    It 'rejects parameter file generation for non-AMBA library types' {
        {
            & $script:NewStructureScriptPath `
                -DefinitionsRootFolder $script:DefinitionsRoot `
                -LibraryPath $script:LibraryRoot `
                -Type ALZ `
                -PacEnvironmentSelector 'epac-dev' `
                -GenerateParameterFile
        } | Should -Throw '-GenerateParameterFile is only supported when -Type is AMBA.'
    }
}
