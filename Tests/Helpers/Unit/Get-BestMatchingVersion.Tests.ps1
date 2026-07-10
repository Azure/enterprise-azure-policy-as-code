BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Compare-SemanticVersion.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-BestMatchingVersion.ps1')
}

Describe 'Get-BestMatchingVersion' {
    It 'returns the highest matching version for a wildcard pin' {
        $result = Get-BestMatchingVersion `
            -PinnedVersion '1.3.*' `
            -AvailableVersions @('1.2.0', '1.3.0', '1.3.1', '1.4.0')
        $result | Should -Be '1.3.1'
    }

    It 'returns the highest matching preview version for a preview wildcard pin' {
        $result = Get-BestMatchingVersion `
            -PinnedVersion '1.3.*-preview' `
            -AvailableVersions @('1.3.0-preview', '1.3.2-preview', '1.3.1-preview')
        $result | Should -Be '1.3.2-preview'
    }

    It 'returns the exact version when an exact pin is provided' {
        $result = Get-BestMatchingVersion `
            -PinnedVersion '1.3.0' `
            -AvailableVersions @('1.2.0', '1.3.0', '1.4.0')
        $result | Should -Be '1.3.0'
    }

    It 'returns null when no version matches the pin' {
        $result = Get-BestMatchingVersion `
            -PinnedVersion '2.0.*' `
            -AvailableVersions @('1.2.0', '1.3.0', '1.4.0')
        $result | Should -BeNullOrEmpty
    }

    It 'returns null for an empty available version list' {
        $result = Get-BestMatchingVersion `
            -PinnedVersion '1.3.*' `
            -AvailableVersions @()
        $result | Should -BeNullOrEmpty
    }

    It 'ignores empty or whitespace available versions' {
        $result = Get-BestMatchingVersion `
            -PinnedVersion '1.3.*' `
            -AvailableVersions @('', '1.3.0', '   ')
        $result | Should -Be '1.3.0'
    }
}
