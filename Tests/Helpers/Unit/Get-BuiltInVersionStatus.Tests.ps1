BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-BuiltInVersionStatus.ps1')
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

Describe 'Get-BuiltInVersionStatus' {

    Context 'assignments which pin a version in the definition files' {

        It 'reports an update when a newer major version of the built-in is published' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '1.*.*' `
                -PolicyDefinition (New-Definition -Version '2.1.0')

            $result.status | Should -Be 'updateAvailable'
            $result.updateAvailable | Should -BeTrue
            $result.assignedMajor | Should -Be 1
            $result.latestMajor | Should -Be 2
            $result.latestVersion | Should -Be '2.1.0'
            $result.assignedVersionFrom | Should -Be 'assignmentFile'
            $result.displayName | Should -Be 'Test built-in'
        }

        It 'reports current when already on the latest major version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '2.*.*' `
                -PolicyDefinition (New-Definition -Version '2.4.1')

            $result.status | Should -Be 'current'
            $result.updateAvailable | Should -BeFalse
        }

        It 'ignores a newer minor or patch version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '2.1.*' `
                -PolicyDefinition (New-Definition -Version '2.9.9')

            $result.status | Should -Be 'current'
        }

        It 'prefers the definition files over the deployed version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '1.*.*' `
                -DeployedDefinitionVersion '3.*.*' `
                -PolicyDefinition (New-Definition -Version '3.0.0')

            $result.assignedVersion | Should -Be '1.*.*'
            $result.assignedVersionFrom | Should -Be 'assignmentFile'
            $result.status | Should -Be 'updateAvailable'
        }
    }

    Context 'assignments which do not pin a version in the definition files' {

        It 'reports an update using the version Azure stamped on the deployed assignment' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DeployedDefinitionVersion '1.*.*' `
                -PolicyDefinition (New-Definition -Version '3.0.0')

            $result.status | Should -Be 'updateAvailable'
            $result.assignedVersion | Should -Be '1.*.*'
            $result.assignedVersionFrom | Should -Be 'deployed'
            $result.assignedMajor | Should -Be 1
            $result.latestMajor | Should -Be 3
        }

        It 'reports current when Azure stamped the latest major version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DeployedDefinitionVersion '3.*.*' `
                -PolicyDefinition (New-Definition -Version '3.0.0')

            $result.status | Should -Be 'current'
            $result.assignedVersionFrom | Should -Be 'deployed'
        }

        It 'reports tracksLatest for a new assignment which is not deployed yet' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -PolicyDefinition (New-Definition -Version '3.0.0')

            $result.status | Should -Be 'tracksLatest'
            $result.updateAvailable | Should -BeFalse
            $result.assignedVersionFrom | Should -Be 'none'
            $result.latestMajor | Should -Be 3
        }

        It 'reports tracksLatest when the deployed assignment has no stamped version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DeployedDefinitionVersion '' `
                -PolicyDefinition (New-Definition -Version '3.0.0')

            $result.status | Should -Be 'tracksLatest'
        }

        It 'reports tracksLatest for a wildcard major version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '*.*.*' `
                -PolicyDefinition (New-Definition -Version '3.0.0')

            $result.status | Should -Be 'tracksLatest'
        }
    }

    Context 'version parsing' {

        It 'falls back to metadata.version when properties.version is absent' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '1.0.0' `
                -PolicyDefinition (New-Definition -MetadataVersion '3.0.0')

            $result.latestVersion | Should -Be '3.0.0'
            $result.status | Should -Be 'updateAvailable'
        }

        It 'ignores a pre-release suffix on either version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '1.*.*-preview' `
                -PolicyDefinition (New-Definition -Version '2.0.0-preview')

            $result.assignedMajor | Should -Be 1
            $result.latestMajor | Should -Be 2
            $result.status | Should -Be 'updateAvailable'
        }

        It 'does not report an update when the built-in is on an older major version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '3.*.*' `
                -PolicyDefinition (New-Definition -Version '2.0.0')

            $result.status | Should -Be 'current'
            $result.updateAvailable | Should -BeFalse
        }
    }

    Context 'cases which cannot produce an advisory' {

        It 'reports custom for a definition which is not a built-in' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '1.*.*' `
                -PolicyDefinition (New-Definition -PolicyType 'Custom' -Version '2.0.0')

            $result.status | Should -Be 'custom'
            $result.updateAvailable | Should -BeFalse
        }

        It 'reports unknown when the built-in publishes no version' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '1.*.*' `
                -PolicyDefinition (New-Definition)

            $result.status | Should -Be 'unknown'
            $result.updateAvailable | Should -BeFalse
        }

        It 'reports unknown when the definition was not loaded' {
            $result = Get-BuiltInVersionStatus `
                -PolicyDefinitionId $script:policyId `
                -DefinitionVersion '1.*.*' `
                -PolicyDefinition $null

            $result.status | Should -Be 'unknown'
            $result.updateAvailable | Should -BeFalse
        }

        It 'always returns a status object so every assignment is accounted for' {
            $result = Get-BuiltInVersionStatus -PolicyDefinitionId $script:policyId -PolicyDefinition $null
            $result | Should -Not -BeNullOrEmpty
            $result.policyDefinitionId | Should -Be $script:policyId
        }
    }
}
