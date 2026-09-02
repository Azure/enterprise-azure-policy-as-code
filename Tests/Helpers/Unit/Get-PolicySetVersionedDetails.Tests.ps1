BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-PolicySetVersionedDetails.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-PolicyResourceProperties.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/RestMethods/Get-AzPolicySetDefinitionVersionsRestMethod.ps1')

    # Convert-PolicySetToDetails writes into the accumulator hashtable it is handed.
    function script:Convert-PolicySetToDetails {
        param ($PolicySetId, $PolicySetDefinition, $PolicySetDetails, $PolicyDetails)
        $PolicySetDetails[$PolicySetId] = @{
            id      = $PolicySetId
            version = $PolicySetDefinition.name
        }
    }

    $script:policySetId = '/providers/Microsoft.Authorization/policySetDefinitions/test-set'
    $script:memberA = '/providers/Microsoft.Authorization/policyDefinitions/member-a'
    $script:memberB = '/providers/Microsoft.Authorization/policyDefinitions/member-b'
    $script:roleA = '/providers/Microsoft.Authorization/roleDefinitions/aaaaaaaa-0000-0000-0000-000000000000'
    $script:roleB = '/providers/Microsoft.Authorization/roleDefinitions/bbbbbbbb-0000-0000-0000-000000000000'

    $script:pacEnvironment = @{
        apiVersions = @{
            policySetDefinitionVersions = '2023-04-01'
            policySetDefinitions        = '2023-04-01'
        }
    }

    $script:policyRoleIds = @{
        $script:memberA = @( $script:roleA )
        $script:memberB = @( $script:roleB )
    }

    function New-Version {
        param (
            [string] $Name,
            [string[]] $Members
        )
        @{
            name       = $Name
            properties = @{
                policyDefinitions = @( $Members | ForEach-Object { @{ policyDefinitionId = $_ } } )
            }
        }
    }
}

Describe 'Get-PolicySetVersionedDetails' {

    BeforeEach {
        $script:allVersions = @(
            New-Version -Name '1.0.0-preview' -Members @( $script:memberA )
            New-Version -Name '1.3.0-preview' -Members @( $script:memberA )
            New-Version -Name '1.4.0' -Members @( $script:memberA, $script:memberB )
            New-Version -Name '1.7.0' -Members @( $script:memberA, $script:memberB )
            New-Version -Name '2.0.0' -Members @( $script:memberB )
        )

        Mock Get-AzPolicySetDefinitionVersionsRestMethod { $script:allVersions }
    }

    Context 'wildcard resolution' {

        It 'resolves XX.*.* to the highest matching stable version' {
            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.resolvedVersion | Should -Be '1.7.0'
            $result.policyRoleDefinitionIds | Should -Be @( $script:roleA, $script:roleB )
        }

        It 'resolves XX.XX.* to the matching minor version' {
            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.4.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.resolvedVersion | Should -Be '1.4.0'
        }

        It 'resolves an exact version' {
            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '2.0.0' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.resolvedVersion | Should -Be '2.0.0'
            $result.policyRoleDefinitionIds | Should -Be @( $script:roleB )
        }
    }

    Context 'pre-release handling' {

        It 'prefers a stable version over a higher pre-release' {
            $script:allVersions = @(
                New-Version -Name '1.4.0' -Members @( $script:memberA )
                New-Version -Name '1.5.0-preview' -Members @( $script:memberB )
            )
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { $script:allVersions }

            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.resolvedVersion | Should -Be '1.4.0'
        }

        It 'falls back to a pre-release when no stable version matches' {
            # Microsoft cloud security benchmark v2 only published 1.3.0-preview for the 1.3 line.
            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.3.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.resolvedVersion | Should -Be '1.3.0-preview'
            $result.policyRoleDefinitionIds | Should -Be @( $script:roleA )
        }

        It 'includes pre-releases when the pattern carries a pre-release suffix' {
            $script:allVersions = @(
                New-Version -Name '1.4.0' -Members @( $script:memberA )
                New-Version -Name '1.5.0-preview' -Members @( $script:memberB )
            )
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { $script:allVersions }

            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*-preview' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.resolvedVersion | Should -Be '1.5.0-preview'
        }

        It 'prefers a pre-release over the same stable core version when one is requested' {
            $script:allVersions = @(
                New-Version -Name '1.4.0' -Members @( $script:memberA )
                New-Version -Name '1.4.0-preview' -Members @( $script:memberB )
            )
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { $script:allVersions }

            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*-preview' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.resolvedVersion | Should -Be '1.4.0-preview'
        }
    }

    Context 'conservative fallbacks' {

        It 'returns null when no published version matches' {
            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '9.*.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result | Should -BeNullOrEmpty
        }

        It 'returns null when the versions endpoint is unavailable' {
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { $null }

            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result | Should -BeNullOrEmpty
        }

        It 'returns null when the Policy Set has no version history' {
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { @() }

            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result | Should -BeNullOrEmpty
        }

        It 'ignores members which contribute no roles' {
            $script:allVersions = @(
                New-Version -Name '1.0.0' -Members @( '/providers/Microsoft.Authorization/policyDefinitions/audit-only' )
            )
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { $script:allVersions }

            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $script:policyRoleIds

            $result.policyRoleDefinitionIds | Should -BeNullOrEmpty
        }

        It 'de-duplicates roles contributed by more than one member' {
            $script:allVersions = @(
                New-Version -Name '1.0.0' -Members @( $script:memberA, $script:memberB )
            )
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { $script:allVersions }
            $duplicateRoleIds = @{
                $script:memberA = @( $script:roleA )
                $script:memberB = @( $script:roleA )
            }

            $result = Get-PolicySetVersionedDetails `
                -PolicySetId $script:policySetId `
                -DefinitionVersion '1.*.*' `
                -PacEnvironment $script:pacEnvironment `
                -PolicyDetails @{} `
                -PolicyRoleIds $duplicateRoleIds

            @($result.policyRoleDefinitionIds).Count | Should -Be 1
        }
    }

    Context 'caching' {

        It 'only queries the versions endpoint once per Policy Set' {
            $cache = @{}
            1..3 | ForEach-Object {
                $null = Get-PolicySetVersionedDetails `
                    -PolicySetId $script:policySetId `
                    -DefinitionVersion '1.*.*' `
                    -PacEnvironment $script:pacEnvironment `
                    -PolicyDetails @{} `
                    -PolicyRoleIds $script:policyRoleIds `
                    -Cache $cache
            }

            Should -Invoke Get-AzPolicySetDefinitionVersionsRestMethod -Times 1 -Exactly
        }

        It 'caches an unavailable versions endpoint so it is not retried' {
            Mock Get-AzPolicySetDefinitionVersionsRestMethod { $null }
            $cache = @{}
            1..3 | ForEach-Object {
                $null = Get-PolicySetVersionedDetails `
                    -PolicySetId $script:policySetId `
                    -DefinitionVersion '1.*.*' `
                    -PacEnvironment $script:pacEnvironment `
                    -PolicyDetails @{} `
                    -PolicyRoleIds $script:policyRoleIds `
                    -Cache $cache
            }

            Should -Invoke Get-AzPolicySetDefinitionVersionsRestMethod -Times 1 -Exactly
        }
    }
}
