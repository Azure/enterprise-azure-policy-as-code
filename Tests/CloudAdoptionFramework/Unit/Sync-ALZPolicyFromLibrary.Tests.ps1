BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'
    $script:DefaultStructureScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/New-ALZPolicyDefaultStructure.ps1'
    $script:DefinitionsRoot = Join-Path $TestDrive 'Definitions'
    $script:LibraryRoot = Join-Path $TestDrive 'library'
    $script:AMBARepoRoot = Join-Path $TestDrive 'amba-source'
    $script:Tag = 'platform/amba/2025.11.0'
    $script:HelperScriptPath = Join-Path $TestDrive 'run-sync.ps1'

    foreach ($path in @(
            $script:DefinitionsRoot
            (Join-Path $script:DefinitionsRoot 'policyStructures')
            (Join-Path $script:DefinitionsRoot 'policyDefinitions')
            (Join-Path $script:DefinitionsRoot 'policyDefinitions/AMBA/monitoring/alerts')
            (Join-Path $script:DefinitionsRoot 'policyAssignments')
            (Join-Path $script:LibraryRoot 'platform/amba/policy_definitions')
            (Join-Path $script:LibraryRoot 'platform/amba/policy_set_definitions')
            (Join-Path $script:LibraryRoot 'platform/amba/archetype_definitions')
            (Join-Path $script:LibraryRoot 'platform/amba/policy_assignments')
            (Join-Path $script:AMBARepoRoot 'services/monitoring/alerts/policy')
        )) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    Set-Content -Path (Join-Path $script:DefinitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

    Set-Content -Path (Join-Path $script:DefinitionsRoot 'policyStructures/amba.policy_default_structure.epac-dev.jsonc') -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {},
  "defaultParameterValues": {},
  "archetypes": []
}
'@

    Set-Content -Path (Join-Path $script:AMBARepoRoot 'services/monitoring/alerts/policy/extended-policy.json') -Value @'
{
  "name": "Extended-Policy-Test",
  "properties": {
    "displayName": "Extended Policy Test",
    "description": "Test policy"
  }
}
'@

    # A policy already present in the ALZ Library (normal sync) — the extended sync must not duplicate it.
    # The input file name ('normal-policy.json') differs from the policy name property; the normal sync
    # uses the 'name' property as the output file name, so output will be 'Normal-Policy-Test.json'.
    Set-Content -Path (Join-Path $script:LibraryRoot 'platform/amba/policy_definitions/normal-policy.json') -Value @'
{
  "name": "Normal-Policy-Test",
  "properties": {
    "displayName": "Normal Policy Test",
    "description": "Test policy from ALZ Library",
    "metadata": { "category": "monitoring" }
  }
}
'@

    # Same policy name as above but sourced from the AMBA services folder — should be skipped by dedup.
    # The file is intentionally named 'duplicate-policy.json' (not matching the policy name) to confirm
    # that dedup is based on the JSON 'name' property, not the file name.
    Set-Content -Path (Join-Path $script:AMBARepoRoot 'services/monitoring/alerts/policy/duplicate-policy.json') -Value @'
{
  "name": "Normal-Policy-Test",
  "properties": {
    "displayName": "Normal Policy Test (duplicate)",
    "description": "Duplicate test policy from AMBA services"
  }
}
'@

    $helperScript = @'
param(
    [switch] $SyncAssignmentsOnly,
    [switch] $SkipExtended,
    [switch] $FailSparseCheckout,
    [string] $LibraryType = 'AMBA'
)

Set-Location $PSScriptRoot

function Invoke-RestMethod {
    param(
        [string] $Uri
    )

    [pscustomobject]@{
        ref = @('__TAG_REF_VALUE__')
    }
}

function git {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Arguments
    )

    if ($Arguments[0] -eq '-C' -and $Arguments[2] -eq 'sparse-checkout' -and
        $Arguments[3] -eq 'set' -and $Arguments[4] -eq 'services') {
        $global:LASTEXITCODE = $FailSparseCheckout ? 1 : 0
        return
    }
    if ($Arguments[0] -ne 'clone' -or (($Arguments -join ' ') -notmatch 'azure-monitor-baseline-alerts\.git') -or
        '--sparse' -notin $Arguments -or 'core.longpaths=true' -notin $Arguments) {
        throw "Unexpected git invocation: $Arguments"
    }

    $destination = $Arguments[-1]
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -Path '__AMBA_REPO_ROOT__/*' -Destination $destination -Recurse -Force | Out-Null
    $global:LASTEXITCODE = 0
}

& '__SYNC_SCRIPT__' `
    -DefinitionsRootFolder '__DEFINITIONS_ROOT__' `
    -LibraryPath '__LIBRARY_ROOT__' `
    -Type $LibraryType `
    -PacEnvironmentSelector 'epac-dev' `
    -Tag '__TAG__' `
    -SyncAMBAExtendedPolicies:(-not $SkipExtended) `
    -SyncAssignmentsOnly:$SyncAssignmentsOnly
'@

    $helperScript = $helperScript.Replace('__SYNC_SCRIPT__', $script:SyncScriptPath.Replace("'", "''"))
    $helperScript = $helperScript.Replace('__DEFINITIONS_ROOT__', $script:DefinitionsRoot.Replace("'", "''"))
    $helperScript = $helperScript.Replace('__LIBRARY_ROOT__', $script:LibraryRoot.Replace("'", "''"))
    $helperScript = $helperScript.Replace('__AMBA_REPO_ROOT__', $script:AMBARepoRoot.Replace("'", "''"))
    $escapedTag = $script:Tag.Replace("'", "''")
    $helperScript = $helperScript.Replace('__TAG__', $escapedTag)
    $helperScript = $helperScript.Replace('__TAG_REF_VALUE__', "refs/tags/$escapedTag")

    Set-Content -Path $script:HelperScriptPath -Value $helperScript
}

AfterAll {
    Remove-Item function:git -ErrorAction SilentlyContinue
    Remove-Item function:Invoke-RestMethod -ErrorAction SilentlyContinue
}

Describe 'Sync-ALZPolicyFromLibrary' {
    It 'uses the current ALZ library release by default' {
        foreach ($scriptPath in @($script:SyncScriptPath, $script:DefaultStructureScriptPath)) {
            (Get-Content -Path $scriptPath -Raw) | Should -Match '\$Tag = "platform/alz/2026\.10\.0"'
        }
    }

    It 'normalizes private DNS zone region display names to the Azure DNS code' {
        $rootStructurePath = Join-Path $script:DefinitionsRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc'
        $minimalLibraryRoot = Join-Path $TestDrive 'private-dns-library'
        foreach ($path in @(
                $minimalLibraryRoot
                (Join-Path $minimalLibraryRoot 'platform/alz/architecture_definitions')
                (Join-Path $minimalLibraryRoot 'platform/alz/archetype_definitions')
                (Join-Path $minimalLibraryRoot 'platform/alz/policy_assignments')
                (Join-Path $minimalLibraryRoot 'platform/alz/policy_definitions')
                (Join-Path $minimalLibraryRoot 'platform/alz/policy_set_definitions')
        )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $minimalLibraryRoot 'platform/alz/architecture_definitions/alz.alz_architecture_definition.json') -Value @'
{
  "management_groups": [
    {
      "id": "root",
      "display_Name": "root",
      "archetypes": ["root"]
    }
  ]
}
'@

        Set-Content -Path (Join-Path $minimalLibraryRoot 'platform/alz/archetype_definitions/root.json') -Value @'
{
  "name": "root",
  "policy_assignments": ["Deploy-Private-DNS-Zones"]
}
'@

        Set-Content -Path (Join-Path $minimalLibraryRoot 'platform/alz/policy_assignments/Deploy-Private-DNS-Zones.alz_policy_assignment.json') -Value @'
{
  "name": "Deploy-Private-DNS-Zones",
  "properties": {
    "parameters": {
      "azureSiteRecoveryBackupPrivateDnsZoneId": {
        "value": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.ne.backup.windowsazure.com"
      }
    }
  }
}
'@

        Set-Content -Path $rootStructurePath -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "root": {
      "management_group_function": "root",
      "value": "/providers/Microsoft.Management/managementGroups/root"
    }
  },
  "defaultParameterValues": {
    "private_dns_zone_region": {
      "parameters": {
        "value": "westeurope"
      }
    },
    "private_dns_zone_subscription_id": {
      "parameters": {
        "value": "00000000-0000-0000-0000-000000000000"
      }
    },
    "private_dns_zone_resource_group_name": {
      "parameters": {
        "value": "test-rg"
      }
    }
  }
}
'@

        & $script:SyncScriptPath `
            -DefinitionsRootFolder $script:DefinitionsRoot `
            -LibraryPath $minimalLibraryRoot `
            -Type ALZ `
            -PacEnvironmentSelector 'epac-dev' | Out-Null

        $outputFile = Get-ChildItem -Path $script:DefinitionsRoot -Recurse -Filter 'Deploy-Private-DNS-Zones*.jsonc' | Select-Object -First 1
        $outputFile | Should -Not -BeNullOrEmpty

        $outputContent = Get-Content -Path $outputFile.FullName -Raw
        $outputContent | Should -Match 'privatelink\.we\.backup\.windowsazure\.com'
        $outputContent | Should -Not -Match 'privatelink\.westeurope\.backup\.windowsazure\.com'
    }

    It 'syncs AMBA extended policy definitions from the secondary repo' {
        & pwsh -NoLogo -NoProfile -File $script:HelperScriptPath | Out-Null
        $LASTEXITCODE | Should -Be 0

        $outputFile = Join-Path $script:DefinitionsRoot 'policyDefinitions/AMBA/monitoring/alerts/extended-policy.json'

        Test-Path $outputFile | Should -BeTrue
        (Get-Content $outputFile -Raw | ConvertFrom-Json).name | Should -Be 'Extended-Policy-Test'
    }

    It 'does not create duplicate policy definitions for policies already synced from the ALZ Library' {
        & pwsh -NoLogo -NoProfile -File $script:HelperScriptPath | Out-Null
        $LASTEXITCODE | Should -Be 0

        # The policy synced from the ALZ Library should exist
        $libraryPolicyFile = Join-Path $script:DefinitionsRoot 'policyDefinitions/AMBA/monitoring/Normal-Policy-Test.json'
        Test-Path $libraryPolicyFile | Should -BeTrue
        (Get-Content $libraryPolicyFile -Raw | ConvertFrom-Json).name | Should -Be 'Normal-Policy-Test'

        # The same-named policy from the AMBA services folder should be skipped
        $duplicateFile = Join-Path $script:DefinitionsRoot 'policyDefinitions/AMBA/monitoring/alerts/duplicate-policy.json'
        Test-Path $duplicateFile | Should -BeFalse
    }

    Context 'AMBA extended policy selectors' {
        BeforeAll {
            $script:StructureSchemaPath = Join-Path $PSScriptRoot '../../../Schemas/policy-structure-schema.json'
            function Invoke-SelectorSync {
                param([switch] $ExpectFailure, [string[]] $Arguments = @())

                $script:SelectorStructure | ConvertTo-Json -Depth 50 | Set-Content $script:SelectorStructurePath
                $output = & pwsh -NoLogo -NoProfile -File $script:SelectorHelper @Arguments 2>&1
                if ($ExpectFailure) {
                    $LASTEXITCODE | Should -Not -Be 0 -Because ($output -join "`n")
                }
                else {
                    $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
                }
                return $output -join "`n"
            }

            foreach ($relativePath in @(
                'services/Compute/virtualMachines/policy/CPU.json'
                'services/Compute/virtualMachines/policy/Memory.json'
                'services/Compute/disks/policy/CPU.json'
                'services/ApiManagement/service/policy/TotalRequests.json'
                'services/ApiManagement/service/policy/Capacity.json'
            )) {
                $path = Join-Path $script:AMBARepoRoot $relativePath
                New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
                @{
                    name = "Policy/$([IO.Path]::GetFileNameWithoutExtension($path))"
                    properties = @{ displayName = 'Selector test policy' }
                } | ConvertTo-Json -Depth 10 | Set-Content $path
            }
            foreach ($folder in @('policy_definitions', 'policy_set_definitions', 'policy_assignments', 'archetype_definitions')) {
                New-Item -ItemType Directory -Path (Join-Path $script:LibraryRoot "platform/alz/$folder") -Force | Out-Null
            }
        }

        BeforeEach {
            $script:SelectorRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path (Join-Path $script:SelectorRoot 'policyStructures') -Force | Out-Null
            Copy-Item (Join-Path $script:DefinitionsRoot 'global-settings.jsonc') $script:SelectorRoot
            $script:SelectorSource = Join-Path $script:SelectorRoot 'source'
            Copy-Item $script:AMBARepoRoot $script:SelectorSource -Recurse
            $script:SelectorHelper = Join-Path $script:SelectorRoot 'run-sync.ps1'
            (Get-Content $script:HelperScriptPath -Raw).Replace(
                $script:DefinitionsRoot.Replace("'", "''"), $script:SelectorRoot.Replace("'", "''")
            ).Replace($script:AMBARepoRoot.Replace("'", "''"), $script:SelectorSource.Replace("'", "''")) | Set-Content $script:SelectorHelper
            $script:SelectorStructure = [pscustomobject]@{
                enforcementMode = 'Default'
                managementGroupNameMappings = [pscustomobject]@{}
                defaultParameterValues = [pscustomobject]@{}
            }
            $script:SelectorStructurePath = Join-Path $script:SelectorRoot 'policyStructures/amba.policy_default_structure.epac-dev.jsonc'
            $script:SelectorOutputRoot = Join-Path $script:SelectorRoot 'policyDefinitions/AMBA'
            $script:SelectorManifestPath = Join-Path $script:SelectorRoot 'policyStructures/amba.extended-policy-manifest.json'
        }

        It 'evaluates <Name>' -TestCases @(
            @{
                Name = 'empty include/exclude groups without restricting sync'
                Filters = '{"include":{"AND":[]},"exclude":{"OR":[]}}'
                Expected = @('Compute/disks/CPU.json', 'Compute/virtualMachines/CPU.json', 'Compute/virtualMachines/Memory.json',
                    'ApiManagement/service/Capacity.json', 'ApiManagement/service/TotalRequests.json', 'monitoring/alerts/extended-policy.json')
            }
            @{
                Name = 'a case-insensitive folder regex relative to services'
                Filters = '{"include":{"type":"folder","pattern":"^compute/virtualmachines/policy$"}}'
                Expected = @('Compute/virtualMachines/CPU.json', 'Compute/virtualMachines/Memory.json')
            }
            @{
                Name = 'the file name and extension rather than the policy name'
                Filters = '{"include":{"type":"file","pattern":"^Memory\\.json$"}}'
                Expected = @('Compute/virtualMachines/Memory.json')
            }
            @{
                Name = 'nested AND and OR across folder and file selectors'
                Filters = '{"include":{"OR":[{"type":"folder","pattern":"^ApiManagement/"},{"AND":[{"type":"folder","pattern":"^Compute/virtualMachines/"},{"OR":[{"type":"file","pattern":"^CPU\\."},{"type":"file","pattern":"^Memory\\."}]}]}]},"exclude":{"AND":[{"type":"folder","pattern":"^ApiManagement/"},{"type":"file","pattern":"TotalRequests"}]}}'
                Expected = @('Compute/virtualMachines/CPU.json', 'Compute/virtualMachines/Memory.json', 'ApiManagement/service/Capacity.json')
            }
            @{
                Name = 'exclusion taking precedence over inclusion'
                Filters = '{"include":{"type":"file","pattern":"Memory"},"exclude":{"type":"folder","pattern":"^Compute/"}}'
                Expected = @()
            }
            @{
                Name = 'an exclusion-only expression'
                Filters = '{"exclude":{"OR":[{"type":"folder","pattern":"^Compute/"},{"type":"file","pattern":"TotalRequests|extended-policy"}]}}'
                Expected = @('ApiManagement/service/Capacity.json')
            }
            @{
                Name = 'a nonmatching inclusion'
                Filters = '{"include":{"type":"folder","pattern":"^DoesNotExist/"}}'
                Expected = @()
            }
        ) {
            param($Name, $Filters, $Expected)

            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ($Filters | ConvertFrom-Json)
            $json = $script:SelectorStructure | ConvertTo-Json -Depth 50
            $json | Test-Json -SchemaFile $script:StructureSchemaPath | Should -BeTrue
            $json | Set-Content $script:SelectorStructurePath

            $output = & pwsh -NoLogo -NoProfile -File $script:SelectorHelper 2>&1
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")

            $outputRoot = Join-Path $script:SelectorRoot 'policyDefinitions/AMBA'
            $actual = @(Get-ChildItem $outputRoot -File -Recurse |
                Where-Object Name -ne 'Normal-Policy-Test.json' |
                ForEach-Object { [IO.Path]::GetRelativePath($outputRoot, $_.FullName).Replace('\', '/') })
            @($actual).Count | Should -Be $Expected.Count
            foreach ($relativePath in $Expected) {
                $actual | Should -Contain $relativePath
            }
            Test-Path (Join-Path $outputRoot 'monitoring/Normal-Policy-Test.json') | Should -BeTrue
            Test-Path (Join-Path $outputRoot 'monitoring/alerts/duplicate-policy.json') | Should -BeFalse
        }

        It 'rejects invalid filters before writing definitions: <Filters>' -TestCases @(
            @{ Filters = 'null' }
            @{ Filters = '[]' }
            @{ Filters = '{"unknown":{}}' }
            @{ Filters = '{"include":null}' }
            @{ Filters = '{"include":{"type":"directory","pattern":".*"}}' }
            @{ Filters = '{"include":{"type":"file","pattern":""}}' }
            @{ Filters = '{"include":{"type":"file","pattern":42}}' }
            @{ Filters = '{"include":{"type":"file","pattern":"["}}' }
            @{ Filters = '{"include":{"type":"file","pattern":".*","extra":true}}' }
            @{ Filters = '{"include":{"AND":{}}}' }
            @{ Filters = '{"include":{"and":[]}}' }
            @{ Filters = '{"include":{"AND":[],"OR":[]}}' }
            @{ Filters = '{"exclude":{"OR":[{"AND":[{"type":"file","pattern":"("}]}]}}' }
        ) {
            param($Filters)

            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ($Filters | ConvertFrom-Json -NoEnumerate)
            $script:SelectorStructure | ConvertTo-Json -Depth 50 | Set-Content $script:SelectorStructurePath
            $output = & pwsh -NoLogo -NoProfile -File $script:SelectorHelper 2>&1

            $LASTEXITCODE | Should -Not -Be 0
            ($output -join "`n") | Should -Match 'ambaExtendedPolicyFilters'
            Test-Path (Join-Path $script:SelectorRoot 'policyDefinitions') | Should -BeFalse
        }

        It 'ignores filters for <Name>' -TestCases @(
            @{ Name = 'AMBA without the extended switch'; Arguments = @('-SkipExtended'); ExpectedLibrary = $true }
            @{ Name = 'assignment-only sync'; Arguments = @('-SyncAssignmentsOnly'); ExpectedLibrary = $false }
            @{ Name = 'ALZ even with the extended switch'; Arguments = @('-LibraryType', 'ALZ'); ExpectedLibrary = $false }
        ) {
            param($Name, $Arguments, $ExpectedLibrary)

            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters 'invalid but ignored'
            $json = $script:SelectorStructure | ConvertTo-Json -Depth 10
            $json | Set-Content $script:SelectorStructurePath
            $json | Set-Content (Join-Path $script:SelectorRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc')
            $output = & pwsh -NoLogo -NoProfile -File $script:SelectorHelper @Arguments 2>&1

            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
            Test-Path (Join-Path $script:SelectorRoot 'policyDefinitions/AMBA/monitoring/Normal-Policy-Test.json') | Should -Be $ExpectedLibrary
            Test-Path (Join-Path $script:SelectorRoot 'policyDefinitions/AMBA/monitoring/alerts/extended-policy.json') | Should -BeFalse
        }

        It 'reconciles consecutive runs when filters narrow, broaden, and are removed' {
            Invoke-SelectorSync | Out-Null
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"type":"file","pattern":"^Memory\\.json$"}}' | ConvertFrom-Json)
            $output = Invoke-SelectorSync
            $output | Should -Match 'Removed extended policy definition'
            @(Get-ChildItem $script:SelectorOutputRoot -Recurse -File).Count | Should -Be 2
            Test-Path (Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/Memory.json') | Should -BeTrue
            Test-Path (Join-Path $script:SelectorOutputRoot 'monitoring/Normal-Policy-Test.json') | Should -BeTrue
            Test-Path $script:SelectorManifestPath | Should -BeFalse

            $script:SelectorStructure.ambaExtendedPolicyFilters = '{"include":{"type":"folder","pattern":"^Compute/"}}' | ConvertFrom-Json
            Invoke-SelectorSync | Out-Null
            @(Get-ChildItem $script:SelectorOutputRoot -Recurse -File).Count | Should -Be 4
            $script:SelectorStructure.PSObject.Properties.Remove('ambaExtendedPolicyFilters')
            Invoke-SelectorSync | Out-Null
            @(Get-ChildItem $script:SelectorOutputRoot -Recurse -File).Count | Should -Be 7
            Invoke-SelectorSync | Out-Null
            @(Get-ChildItem $script:SelectorOutputRoot -Recurse -File).Count | Should -Be 7
            Test-Path $script:SelectorManifestPath | Should -BeFalse
        }

        It 'removes all identifiable extended files for zero matches and preserves custom and library files' {
            Invoke-SelectorSync | Out-Null
            $customPath = Join-Path $script:SelectorOutputRoot 'custom.json'
            '{"name":"Custom","properties":{}}' | Set-Content $customPath
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)

            $output = Invoke-SelectorSync
            $output | Should -Match 'Ambiguous AMBA policy file.*custom.json'
            @(Get-ChildItem $script:SelectorOutputRoot -Recurse -File).Count | Should -Be 2
            Test-Path $customPath | Should -BeTrue
            Test-Path (Join-Path $script:SelectorOutputRoot 'monitoring/Normal-Policy-Test.json') | Should -BeTrue
            Test-Path $script:SelectorManifestPath | Should -BeFalse
        }

        It 'removes nested empty folders after cleanup but preserves the root and folders containing hidden files' {
            Invoke-SelectorSync | Out-Null
            $emptyPath = Join-Path $script:SelectorOutputRoot 'unused/nested/empty'
            $hiddenFolder = Join-Path $script:SelectorOutputRoot 'custom/hidden'
            New-Item -ItemType Directory -Path $emptyPath, $hiddenFolder -Force | Out-Null
            $hiddenFile = Join-Path $hiddenFolder '.keep'
            'keep' | Set-Content -LiteralPath $hiddenFile
            if ($IsWindows) {
                (Get-Item -LiteralPath $hiddenFile -Force).Attributes = [IO.FileAttributes]::Hidden
            }
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)

            $output = Invoke-SelectorSync
            $output | Should -Match 'Removed empty AMBA policy folder'
            Test-Path (Join-Path $script:SelectorOutputRoot 'unused') | Should -BeFalse
            Test-Path (Join-Path $script:SelectorOutputRoot 'Compute') | Should -BeFalse
            Test-Path (Join-Path $script:SelectorOutputRoot 'ApiManagement') | Should -BeFalse
            Test-Path (Join-Path $script:SelectorOutputRoot 'monitoring/alerts') | Should -BeFalse
            Test-Path (Join-Path $script:SelectorOutputRoot 'monitoring/Normal-Policy-Test.json') | Should -BeTrue
            Test-Path $script:SelectorOutputRoot -PathType Container | Should -BeTrue
            Test-Path $hiddenFolder -PathType Container | Should -BeTrue
            Test-Path $hiddenFile | Should -BeTrue
        }

        It 'identifies generated files but reports modified and unidentifiable files' {
            Invoke-SelectorSync | Out-Null
            $modifiedPath = Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/CPU.json'
            $invalidPath = Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/Memory.json'
            $unknownPath = Join-Path $script:SelectorOutputRoot 'monitoring/alerts/removed-upstream.json'
            '{"name":"Policy_CPU","properties":{"displayName":"User changes"}}' | Set-Content $modifiedPath
            'not JSON' | Set-Content $invalidPath
            '{"name":"No longer upstream","properties":{}}' | Set-Content $unknownPath
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)

            $output = Invoke-SelectorSync
            $output | Should -Match 'Ambiguous AMBA policy file.*CPU.json'
            $output | Should -Match 'Ambiguous AMBA policy file.*Memory.json.*not valid JSON'
            $output | Should -Match 'Ambiguous AMBA policy file.*removed-upstream.json'
            Test-Path $modifiedPath | Should -BeTrue
            Test-Path $invalidPath | Should -BeTrue
            Test-Path $unknownPath | Should -BeTrue
            Test-Path (Join-Path $script:SelectorOutputRoot 'ApiManagement/service/TotalRequests.json') | Should -BeFalse
            Test-Path (Join-Path $script:SelectorOutputRoot 'monitoring/Normal-Policy-Test.json') | Should -BeTrue
        }

        It 'preserves files modified locally both when selected and excluded' {
            Invoke-SelectorSync | Out-Null
            $modifiedPath = Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/CPU.json'
            $modifiedContent = '{"name":"Policy_CPU","properties":{"displayName":"User changes"}}'
            $modifiedContent | Set-Content $modifiedPath -NoNewline
            $output = Invoke-SelectorSync
            $output | Should -Match 'Ambiguous AMBA policy file.*CPU.json'
            (Get-Content $modifiedPath -Raw) | Should -Be $modifiedContent
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)
            $output = Invoke-SelectorSync
            $output | Should -Match 'Ambiguous AMBA policy file.*CPU.json'
            (Get-Content $modifiedPath -Raw) | Should -Be $modifiedContent
        }

        It 'reports files removed or changed upstream as ambiguous rather than deleting or overwriting them' {
            Invoke-SelectorSync | Out-Null
            Remove-Item -LiteralPath (Join-Path $script:SelectorSource 'services/Compute/virtualMachines/policy/CPU.json')
            $memorySource = Join-Path $script:SelectorSource 'services/Compute/virtualMachines/policy/Memory.json'
            $memoryPolicy = Get-Content $memorySource -Raw | ConvertFrom-Json
            $memoryPolicy.properties.displayName = 'Updated upstream'
            $memoryPolicy | ConvertTo-Json -Depth 10 | Set-Content $memorySource
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)
            $output = Invoke-SelectorSync
            $output | Should -Match 'Ambiguous AMBA policy file.*CPU.json'
            $output | Should -Match 'Ambiguous AMBA policy file.*Memory.json'
            Test-Path (Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/CPU.json') | Should -BeTrue
            $memoryPath = Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/Memory.json'
            (Get-Content $memoryPath -Raw | ConvertFrom-Json).properties.displayName | Should -Be 'Selector test policy'
            Test-Path (Join-Path $script:SelectorOutputRoot 'ApiManagement/service/Capacity.json') | Should -BeFalse
        }

        It 'protects normal-library outputs when an extended policy <Name>' -TestCases @(
            @{ Name = 'moves into the library'; PolicyName = 'Policy_Memory'; Category = 'monitoring'; ExtendedRemains = $false }
            @{ Name = 'collides with a library output path'; PolicyName = 'Memory'; Category = 'Compute/virtualMachines'; ExtendedRemains = $true }
        ) {
            param($Name, $PolicyName, $Category, $ExtendedRemains)

            Invoke-SelectorSync | Out-Null
            $localLibrary = Join-Path $script:SelectorRoot 'library'
            Copy-Item $script:LibraryRoot $localLibrary -Recurse
            (Get-Content $script:SelectorHelper -Raw).Replace(
                $script:LibraryRoot.Replace("'", "''"), $localLibrary.Replace("'", "''")
            ) | Set-Content $script:SelectorHelper
            @{
                name = $PolicyName
                properties = @{
                    displayName = 'Normal-library definition'
                    metadata = @{ category = $Category }
                }
            } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $localLibrary 'platform/amba/policy_definitions/promoted.json')
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)

            Invoke-SelectorSync | Out-Null
            $normalPath = Join-Path $script:SelectorOutputRoot "$Category/$PolicyName.json"
            (Get-Content $normalPath -Raw | ConvertFrom-Json).properties.displayName | Should -Be 'Normal-library definition'
            Test-Path (Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/Memory.json') | Should -Be $ExtendedRemains
            Test-Path $script:SelectorManifestPath | Should -BeFalse
        }

        It 'does not prune on a <Name>' -TestCases @(
            @{ Name = 'source JSON error'; Failure = 'json' }
            @{ Name = 'source enumeration error'; Failure = 'missing-source' }
            @{ Name = 'source catalogue with no policies'; Failure = 'empty-source' }
            @{ Name = 'regex error'; Failure = 'regex' }
            @{ Name = 'write error'; Failure = 'write' }
        ) {
            param($Name, $Failure)

            Invoke-SelectorSync | Out-Null
            $preservedPath = Join-Path $script:SelectorOutputRoot 'monitoring/alerts/extended-policy.json'
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"type":"file","pattern":"Memory"}}' | ConvertFrom-Json)
            switch ($Failure) {
                'json' { 'invalid' | Set-Content (Join-Path $script:SelectorSource 'services/Compute/virtualMachines/policy/Memory.json') }
                'missing-source' { Rename-Item (Join-Path $script:SelectorSource 'services') 'missing-services' }
                'empty-source' {
                    Get-ChildItem (Join-Path $script:SelectorSource 'services') -Recurse -File | Remove-Item
                }
                'regex' { $script:SelectorStructure.ambaExtendedPolicyFilters.include.pattern = '[' }
                'write' {
                    $blockedPath = Join-Path $script:SelectorOutputRoot 'Compute/virtualMachines/Memory.json'
                    Remove-Item -LiteralPath $blockedPath
                    New-Item -ItemType Directory -Path $blockedPath | Out-Null
                }
            }
            Invoke-SelectorSync -ExpectFailure | Out-Null
            Test-Path $preservedPath | Should -BeTrue
            if ($Failure -eq 'write') {
                Remove-Item -LiteralPath $blockedPath
                Invoke-SelectorSync | Out-Null
                Test-Path $preservedPath | Should -BeFalse
                Test-Path $blockedPath -PathType Leaf | Should -BeTrue
            }
        }

        It 'does not read or modify an obsolete manifest or files referenced by it' {
            Invoke-SelectorSync | Out-Null
            $outsidePath = Join-Path $script:SelectorRoot 'do-not-delete.json'
            'keep' | Set-Content $outsidePath
            $obsoleteManifest = '{"version":1,"policies":[{"path":"../../do-not-delete.json"}]}'
            $obsoleteManifest | Set-Content $script:SelectorManifestPath -NoNewline
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)
            Invoke-SelectorSync | Out-Null
            (Get-Content $script:SelectorManifestPath -Raw) | Should -Be $obsoleteManifest
            (Get-Content $outsidePath -Raw).Trim() | Should -Be 'keep'
            Test-Path (Join-Path $script:SelectorOutputRoot 'monitoring/alerts/extended-policy.json') | Should -BeFalse
        }

        It 'stops before reconciliation if checking out the services folder fails' {
            Invoke-SelectorSync | Out-Null
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)
            $output = Invoke-SelectorSync -ExpectFailure -Arguments @('-FailSparseCheckout')
            $output | Should -Match 'Failed to check out AMBA extended policy services'
            Test-Path $script:SelectorManifestPath | Should -BeFalse
            @(Get-ChildItem $script:SelectorOutputRoot -Recurse -File).Count | Should -Be 7
        }

        It 'does not reconcile existing extended files for <Name>' -TestCases @(
            @{ Name = 'AMBA without the extended switch'; Arguments = @('-SkipExtended') }
            @{ Name = 'assignment-only sync'; Arguments = @('-SyncAssignmentsOnly') }
            @{ Name = 'ALZ even with the extended switch'; Arguments = @('-LibraryType', 'ALZ') }
        ) {
            param($Name, $Arguments)

            Invoke-SelectorSync | Out-Null
            $emptyPath = Join-Path $script:SelectorOutputRoot 'unused/nested'
            New-Item -ItemType Directory -Path $emptyPath -Force | Out-Null
            $script:SelectorStructure | Add-Member ambaExtendedPolicyFilters ('{"include":{"OR":[]}}' | ConvertFrom-Json)
            $script:SelectorStructure | ConvertTo-Json -Depth 50 |
                Set-Content (Join-Path $script:SelectorRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc')
            Invoke-SelectorSync -Arguments $Arguments | Out-Null
            Test-Path $script:SelectorManifestPath | Should -BeFalse
            @(Get-ChildItem $script:SelectorOutputRoot -Recurse -File).Count | Should -Be 7
            Test-Path $emptyPath -PathType Container | Should -BeTrue
        }
    }
}
