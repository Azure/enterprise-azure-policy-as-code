BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-BuiltInMajorVersionUpdate.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-PolicyResourceProperties.ps1')

    $script:policyId = '/providers/Microsoft.Authorization/policyDefinitions/test-policy'

    function New-Definition {
        param (
            [string] $PolicyType = 'BuiltIn',
            [string] $Version,
            [string] $MetadataVersion,
            [string] $DisplayName = 'Test built-in'
        )
        $properties = @{
            policyType  = $PolicyType
            displayName = $DisplayName
        }
        if ($Version) {
            $properties.version = $Version
        }
        if ($MetadataVersion) {
            $properties.metadata = @{ version = $MetadataVersion }
        }
        @{
            name       = 'test-policy'
            properties = $properties
        }
    }
}

Describe 'Get-BuiltInMajorVersionUpdate' {

    It 'reports an advisory when a newer major version of a built-in is published' {
        $result = Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '1.*.*' `
            -PolicyDefinition (New-Definition -Version '2.1.0')

        $result | Should -Not -BeNullOrEmpty
        $result.assignedMajor | Should -Be 1
        $result.latestMajor | Should -Be 2
        $result.latestVersion | Should -Be '2.1.0'
        $result.assignedVersion | Should -Be '1.*.*'
        $result.policyDefinitionId | Should -Be $script:policyId
        $result.displayName | Should -Be 'Test built-in'
    }

    It 'falls back to metadata.version when properties.version is absent' {
        $result = Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '1.0.0' `
            -PolicyDefinition (New-Definition -MetadataVersion '3.0.0')

        $result.latestMajor | Should -Be 3
        $result.latestVersion | Should -Be '3.0.0'
    }

    It 'ignores a pre-release suffix on either version' {
        $result = Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '1.*.*-preview' `
            -PolicyDefinition (New-Definition -Version '2.0.0-preview')

        $result.assignedMajor | Should -Be 1
        $result.latestMajor | Should -Be 2
    }

    It 'returns null when the assignment is already on the latest major version' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '2.*.*' `
            -PolicyDefinition (New-Definition -Version '2.4.1') | Should -BeNullOrEmpty
    }

    It 'returns null when only a minor or patch version is newer' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '2.1.0' `
            -PolicyDefinition (New-Definition -Version '2.9.9') | Should -BeNullOrEmpty
    }

    It 'returns null when the built-in is on an older major version than the assignment' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '3.*.*' `
            -PolicyDefinition (New-Definition -Version '2.0.0') | Should -BeNullOrEmpty
    }

    It 'returns null for custom definitions' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '1.*.*' `
            -PolicyDefinition (New-Definition -PolicyType 'Custom' -Version '2.0.0') | Should -BeNullOrEmpty
    }

    It 'returns null when the assignment does not pin a definitionVersion' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '' `
            -PolicyDefinition (New-Definition -Version '2.0.0') | Should -BeNullOrEmpty
    }

    It 'returns null when the assignment wildcards the major version' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '*.*.*' `
            -PolicyDefinition (New-Definition -Version '2.0.0') | Should -BeNullOrEmpty
    }

    It 'returns null when the built-in publishes no version' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '1.*.*' `
            -PolicyDefinition (New-Definition) | Should -BeNullOrEmpty
    }

    It 'returns null when the definition is not available' {
        Get-BuiltInMajorVersionUpdate `
            -PolicyDefinitionId $script:policyId `
            -DefinitionVersion '1.*.*' `
            -PolicyDefinition $null | Should -BeNullOrEmpty
    }
}
