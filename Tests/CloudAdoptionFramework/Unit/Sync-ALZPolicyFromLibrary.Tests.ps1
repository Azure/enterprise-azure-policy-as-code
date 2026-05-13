BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\CloudAdoptionFrameworkTestHelpers.ps1')
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:NewScript = Join-Path $script:RepoRoot 'Scripts\CloudAdoptionFramework\New-ALZPolicyDefaultStructure.ps1'
    $script:SyncScript = Join-Path $script:RepoRoot 'Scripts\CloudAdoptionFramework\Sync-ALZPolicyFromLibrary.ps1'
}

Describe 'Sync-ALZPolicyFromLibrary' {
    It 'creates ALZ definitions and assignments from fixture content' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-CreateAlz')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library-CreateAlz') -Types @('ALZ')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot
        & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot

        (Test-Path -Path (Join-Path $definitionsRoot 'policyDefinitions\ALZ\General\Audit-Policy.json')) | Should -BeTrue
        (Test-Path -Path (Join-Path $definitionsRoot 'policySetDefinitions\ALZ\General\Deploy-Base.json')) | Should -BeTrue
        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Root\Deploy-Base.jsonc')) | Should -BeTrue
        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Landing Zones\Deploy-Private-DNS-Zones.jsonc')) | Should -BeTrue

        $dnsAssignment = Get-TestJsonFile -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Landing Zones\Deploy-Private-DNS-Zones.jsonc')
        $dnsAssignment.additionalRoleAssignments.'epac-dev'[0].scope | Should -Be '/subscriptions/11111111-1111-1111-1111-111111111111'
        $dnsAssignment.nodeName | Should -Be 'landing_zones/Deploy-Private-DNS-Zones'

        $definitionFallbackAssignment = Get-TestJsonFile -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Root\Audit-Policy.jsonc')
        $definitionFallbackAssignment.definitionEntry.policyName | Should -Be 'Audit-Policy'
    }

    It 'supports SyncAssignmentsOnly without creating policy definition files' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-SyncAssignmentsOnly')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library-SyncAssignmentsOnly') -Types @('ALZ')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot
        & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot -SyncAssignmentsOnly

        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Root\Deploy-Base.jsonc')) | Should -BeTrue
        (Test-Path -Path (Join-Path $definitionsRoot 'policyDefinitions\ALZ\General\Audit-Policy.json')) | Should -BeFalse
        (Test-Path -Path (Join-Path $definitionsRoot 'policySetDefinitions\ALZ\General\Deploy-Base.json')) | Should -BeFalse
    }

    It 'applies overrides for ignored archetypes, custom archetypes, parameters, and enforcement mode' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-Overrides')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library-Overrides') -Types @('ALZ')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot

        $structurePath = Join-Path $definitionsRoot 'policyStructures\alz.policy_default_structure.epac-dev.jsonc'
        $structure = Get-TestJsonFile -Path $structurePath -AsHashtable
        $structure.managementGroupNameMappings['custom_identity'] = [ordered]@{
            management_group_function = 'Custom Identity'
            value                     = '/providers/Microsoft.Management/managementGroups/custom-identity'
        }
        $structure.managementGroupNameMappings['custom_landing'] = [ordered]@{
            management_group_function = 'Custom Landing'
            value                     = '/providers/Microsoft.Management/managementGroups/custom-landing'
        }
        $structure.overrides = [ordered]@{
            archetypes      = [ordered]@{
                ignore = @('platform')
                custom = @(
                    [ordered]@{
                        name                         = 'identity'
                        type                         = 'existing'
                        policy_assignments_to_add    = @('Deploy-Private-DNS-Zones')
                        policy_assignments_to_remove = @('Deploy-Base')
                    },
                    [ordered]@{
                        name                      = 'custom_identity'
                        type                      = 'existing'
                        based_on                  = 'identity'
                        policy_assignments_to_add = @('Deploy-Base')
                    },
                    [ordered]@{
                        name               = 'custom_landing'
                        type               = 'new'
                        policy_assignments = @('Deploy-Private-DNS-Zones')
                    }
                )
            }
            parameters      = [ordered]@{
                custom_identity = @(
                    [ordered]@{
                        policy_assignment_name = 'Deploy-Base'
                        parameters             = @(
                            [ordered]@{
                                parameter_name = 'effect'
                                value          = 'Deny'
                            }
                        )
                    }
                )
            }
            enforcementMode = [ordered]@{
                Default      = @()
                DoNotEnforce = @('identity/Deploy-Private-DNS-Zones', 'custom_identity/Deploy-Base')
            }
        }
        Set-TestJsonFile -Path $structurePath -Object $structure

        & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot -EnableOverrides

        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Platform\Enforce-GR-Test0.jsonc')) | Should -BeFalse
        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Identity\Deploy-Base.jsonc')) | Should -BeFalse
        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Identity\Deploy-Private-DNS-Zones.jsonc')) | Should -BeTrue
        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Custom Identity\Deploy-Base.jsonc')) | Should -BeTrue
        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Custom Landing\Deploy-Private-DNS-Zones.jsonc')) | Should -BeTrue

        $identityAssignment = Get-TestJsonFile -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Identity\Deploy-Private-DNS-Zones.jsonc')
        $identityAssignment.enforcementMode | Should -Be 'DoNotEnforce'

        $customIdentityAssignment = Get-TestJsonFile -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Custom Identity\Deploy-Base.jsonc')
        $customIdentityAssignment.enforcementMode | Should -Be 'DoNotEnforce'
        $customIdentityAssignment.parameters.effect | Should -Be 'Deny'
    }

    It 'includes guardrail assignments only when requested' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-GuardrailDefault')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library-GuardrailDefault') -Types @('ALZ')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot
        & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot

        (Test-Path -Path (Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Platform\Enforce-GRTest0.jsonc')) | Should -BeFalse

        $definitionsWithGuardrails = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-GuardrailEnabled')
        & $script:NewScript -DefinitionsRootFolder $definitionsWithGuardrails -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot
        & $script:SyncScript -DefinitionsRootFolder $definitionsWithGuardrails -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot -CreateGuardrailAssignments

        (Test-Path -Path (Join-Path $definitionsWithGuardrails 'policyAssignments\ALZ\epac-dev\Platform\Enforce-GR-Test0.jsonc')) | Should -BeTrue
    }

    It 'syncs AMBA extended policy definitions when requested' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-AmbaExtended')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library-AmbaExtended') -Types @('AMBA')
        $extendedRoot = Join-Path $TestDrive 'AMBAExtended'
        New-AmbaExtendedFixtureLibrary -LibraryRoot $extendedRoot

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type AMBA -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot
        Push-Location $TestDrive
        try {
            Invoke-WithMockedGitClone -CloneMap @{
                'https://github.com/Azure/azure-monitor-baseline-alerts.git' = $extendedRoot
            } -ScriptBlock {
                & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type AMBA -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot -SyncAMBAExtendedPolicies
            }
        }
        finally {
            Pop-Location
        }

        (Test-Path -Path (Join-Path $definitionsRoot 'policyDefinitions\AMBA\Compute\virtualMachines\amba-extended-alert.json')) | Should -BeTrue
    }

    It 'removes obsolete assignments after a subsequent sync' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-Cleanup')
        $initialLibrary = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'LibraryInitial') -Types @('ALZ')
        $updatedLibrary = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'LibraryUpdated') -Types @('ALZ') -AlzVariant 'withoutPrivateDns'

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $initialLibrary
        & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $initialLibrary

        $dnsAssignmentPath = Join-Path $definitionsRoot 'policyAssignments\ALZ\epac-dev\Landing Zones\Deploy-Private-DNS-Zones.jsonc'
        (Test-Path -Path $dnsAssignmentPath) | Should -BeTrue

        & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $updatedLibrary

        (Test-Path -Path $dnsAssignmentPath) | Should -BeFalse
    }

    It 'fails with guidance when the policy structure file is missing' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'MissingStructureDefinitions')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library-MissingStructure') -Types @('ALZ')

        $result = Invoke-TestPwshFile -ScriptPath $script:SyncScript -Parameters @{
            DefinitionsRootFolder  = $definitionsRoot
            Type                   = 'ALZ'
            PacEnvironmentSelector = 'epac-dev'
            LibraryPath            = $libraryRoot
        } -WorkingDirectory $script:RepoRoot -ArtifactRoot $TestDrive

        $result.Output | Should -Match 'Please run New-ALZPolicyDefaultStructure.ps1 first'
    }

    It 'creates SLZ assignments with resolved composite scopes' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions-Slz')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library-Slz') -Types @('SLZ')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type SLZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot
        & $script:SyncScript -DefinitionsRootFolder $definitionsRoot -Type SLZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot

        $controlsAssignmentPath = (Get-ChildItem -Path (Join-Path $definitionsRoot 'policyAssignments\SLZ\epac-dev') -Recurse -Filter 'Deploy-SLZ-L2-Controls.jsonc' | Select-Object -First 1).FullName
        $sharedAssignmentPath = (Get-ChildItem -Path (Join-Path $definitionsRoot 'policyAssignments\SLZ\epac-dev') -Recurse -Filter 'Deploy-SLZ-Shared.jsonc' | Select-Object -First 1).FullName
        $controlsAssignment = Get-TestJsonFile -Path $controlsAssignmentPath
        $sharedAssignment = Get-TestJsonFile -Path $sharedAssignmentPath

        @($controlsAssignment.scope.'epac-dev') | Should -Contain '/providers/Microsoft.Management/managementGroups/l2'
        @($sharedAssignment.scope.'epac-dev') | Should -Contain '/providers/Microsoft.Management/managementGroups/l2'
    }
}
