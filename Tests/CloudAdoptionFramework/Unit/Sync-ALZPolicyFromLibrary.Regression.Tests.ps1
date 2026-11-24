BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'

    function Write-SyncFixture {
        $script:Structure | ConvertTo-Json -Depth 50 | Set-Content $script:StructurePath
        $script:Archetype | ConvertTo-Json -Depth 50 | Set-Content $script:ArchetypePath
        $script:LibraryAssignment | ConvertTo-Json -Depth 50 | Set-Content $script:AssignmentPath
    }

    function Invoke-SyncFixture {
        param([bool] $AssignmentsOnly = $true)
        Write-SyncFixture
        $arguments = @{
            DefinitionsRootFolder = $script:DefinitionsRoot
            LibraryPath = $script:LibraryRoot
            Type = 'ALZ'
            PacEnvironmentSelector = 'epac-dev'
            EnableOverrides = $true
        }
        if ($AssignmentsOnly) { $arguments.SyncAssignmentsOnly = $true }
        & $script:SyncScriptPath @arguments
    }

    function Read-SyncAssignment {
        param([string] $Category = 'Platform')
        Get-Content (Join-Path $script:DefinitionsRoot "policyAssignments/ALZ/epac-dev/$Category/$($script:LibraryAssignment.name).jsonc") -Raw |
            ConvertFrom-Json
    }

    function git {
        param([Parameter(ValueFromRemainingArguments)] [string[]] $Arguments)
        throw "Unexpected real git invocation: $Arguments"
    }
}

Describe 'ALZ sync assignment regressions' {
    BeforeEach {
        $script:CaseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:DefinitionsRoot = Join-Path $script:CaseRoot 'Definitions'
        $script:LibraryRoot = Join-Path $script:CaseRoot 'library'
        foreach ($folder in @(
            (Join-Path $script:DefinitionsRoot 'policyStructures')
            (Join-Path $script:LibraryRoot 'platform/alz/archetype_definitions')
            (Join-Path $script:LibraryRoot 'platform/alz/policy_assignments')
            (Join-Path $script:LibraryRoot 'platform/alz/policy_definitions')
            (Join-Path $script:LibraryRoot 'platform/alz/policy_set_definitions')
        )) {
            $null = New-Item -ItemType Directory -Path $folder -Force
        }
        '{"telemetryOptOut":true,"pacEnvironments":["epac-dev"]}' |
            Set-Content (Join-Path $script:DefinitionsRoot 'global-settings.jsonc')
        $script:StructurePath = Join-Path $script:DefinitionsRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc'
        $script:ArchetypePath = Join-Path $script:LibraryRoot 'platform/alz/archetype_definitions/platform.json'
        $script:AssignmentPath = Join-Path $script:LibraryRoot 'platform/alz/policy_assignments/Deploy-VM-ChangeTrack.alz_policy_assignment.json'
        $script:Structure = @{
            enforcementMode = 'Default'
            managementGroupNameMappings = @{
                platform = @{
                    management_group_function = 'Platform'
                    value = '/providers/Microsoft.Management/managementGroups/platform'
                }
            }
            defaultParameterValues = @{}
            overrides = @{ archetypes = @{ custom = @() } }
        }
        $script:Archetype = @{ name = 'platform'; policy_assignments = @('Deploy-VM-ChangeTrack') }
        $script:DcrId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr'
        $script:IdentityId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ama'
        $script:LibraryAssignment = @{
            name = 'Deploy-VM-ChangeTrack'
            properties = @{
                displayName = 'Change tracking'
                description = 'Change tracking test'
                policyDefinitionId = '/providers/Microsoft.Authorization/policySetDefinitions/Deploy-VM-ChangeTrack'
                parameters = @{
                    effect = @{ value = 'Disabled' }
                    dcrResourceId = @{ value = $script:DcrId }
                    userAssignedIdentityResourceId = @{ value = $script:IdentityId }
                    bringYourOwnUserAssignedManagedIdentity = @{ value = $true }
                    restrictBringYourOwnUserAssignedIdentityToSubscription = @{ value = $false }
                }
            }
        }
    }

    It 'skips each role independently when <Parameter> is <Kind>' -TestCases @(
        @{ Parameter = 'dcrResourceId'; Kind = 'missing' }
        @{ Parameter = 'dcrResourceId'; Kind = 'null' }
        @{ Parameter = 'dcrResourceId'; Kind = 'empty' }
        @{ Parameter = 'dcrResourceId'; Kind = 'whitespace' }
        @{ Parameter = 'userAssignedIdentityResourceId'; Kind = 'missing' }
        @{ Parameter = 'userAssignedIdentityResourceId'; Kind = 'null' }
        @{ Parameter = 'userAssignedIdentityResourceId'; Kind = 'empty' }
        @{ Parameter = 'userAssignedIdentityResourceId'; Kind = 'whitespace' }
    ) {
        param($Parameter, $Kind)
        if ($Kind -eq 'missing') {
            $script:LibraryAssignment.properties.parameters.Remove($Parameter)
        }
        else {
            $script:LibraryAssignment.properties.parameters[$Parameter].value = switch ($Kind) {
                'null' { $null }
                'empty' { '' }
                'whitespace' { " `t " }
            }
        }
        Invoke-SyncFixture | Out-Null
        $assignment = Read-SyncAssignment
        $roles = @($assignment.additionalRoleAssignments.'epac-dev')
        $roles | Should -HaveCount 1
        $roles[0].scope | Should -Be ($Parameter -eq 'dcrResourceId' ? $script:IdentityId : $script:DcrId)
        $assignment.parameters.effect | Should -Be 'Disabled'
    }

    It 'omits additional roles when both target IDs are blank' {
        $script:LibraryAssignment.properties.parameters.dcrResourceId.value = ''
        $script:LibraryAssignment.properties.parameters.userAssignedIdentityResourceId.value = " `t "
        Invoke-SyncFixture | Out-Null
        (Read-SyncAssignment).PSObject.Properties.Name | Should -Not -Contain 'additionalRoleAssignments'
    }

    It 'preserves the identity conditions when <Parameter> is <Value>' -TestCases @(
        @{ Parameter = 'bringYourOwnUserAssignedManagedIdentity'; Value = $false }
        @{ Parameter = 'restrictBringYourOwnUserAssignedIdentityToSubscription'; Value = $true }
    ) {
        param($Parameter, $Value)
        $script:LibraryAssignment.properties.parameters[$Parameter].value = $Value
        Invoke-SyncFixture | Out-Null
        $roles = @((Read-SyncAssignment).additionalRoleAssignments.'epac-dev')
        $roles | Should -HaveCount 1
        $roles[0].scope | Should -Be $script:DcrId
    }

    It 'does not let an unresolved override change the following assignment' {
        $script:LibraryAssignment.properties.definitionVersion = '2.*.*'
        $script:LibraryAssignment.properties.nonComplianceMessages = @(@{ message = 'Resources {enforcementMode} comply.' })
        Invoke-SyncFixture | Out-Null
        $before = Read-SyncAssignment | ConvertTo-Json -Depth 50 -Compress
        $script:Structure.overrides.archetypes.custom = @(@{
            name = 'platform'; type = 'existing'
            policy_assignments_to_remove = @('Deploy-VM-ChangeTrack')
            policy_assignments_to_add = @('Deploy-Missing-X', 'Deploy-VM-ChangeTrack')
        })
        $output = Invoke-SyncFixture 6>&1 | Out-String
        $output | Should -Match 'Skipping unresolved policy definition'
        (Read-SyncAssignment | ConvertTo-Json -Depth 50 -Compress) | Should -Be $before
    }

    It 'removes the old output path without affecting another environment or scope with the same name' {
        $script:Structure.managementGroupNameMappings.corp = @{
            management_group_function = 'Corp'
            value = '/providers/Microsoft.Management/managementGroups/corp'
        }
        @{ name = 'corp'; policy_assignments = @('Deploy-VM-ChangeTrack') } | ConvertTo-Json |
            Set-Content (Join-Path $script:LibraryRoot 'platform/alz/archetype_definitions/corp.json')
        Invoke-SyncFixture | Out-Null
        $oldPath = Join-Path $script:DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Platform/Deploy-VM-ChangeTrack.jsonc'
        $otherPath = Join-Path $script:DefinitionsRoot 'policyAssignments/ALZ/other/Deploy-VM-ChangeTrack.jsonc'
        $null = New-Item -ItemType Directory -Path (Split-Path $otherPath) -Force
        Copy-Item $oldPath $otherPath
        $otherHash = (Get-FileHash $otherPath).Hash
        $script:Structure.managementGroupNameMappings.platform.management_group_function = 'Moved'
        Invoke-SyncFixture | Out-Null
        Test-Path $oldPath | Should -BeFalse
        (Read-SyncAssignment -Category 'Moved').assignment.name | Should -Be 'Deploy-VM-ChangeTrack'
        (Read-SyncAssignment -Category 'Corp').assignment.name | Should -Be 'Deploy-VM-ChangeTrack'
        (Get-FileHash $otherPath).Hash | Should -Be $otherHash
    }

    It 'removes an assignment excluded by an override after generation succeeds' {
        Invoke-SyncFixture | Out-Null
        $script:Structure.overrides.archetypes.custom = @(@{
            name = 'platform'; type = 'existing'
            policy_assignments_to_remove = @('Deploy-VM-ChangeTrack')
        })
        Invoke-SyncFixture | Out-Null
        Test-Path (Join-Path $script:DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Platform/Deploy-VM-ChangeTrack.jsonc') |
            Should -BeFalse
    }

    It 'throws a catchable error for invalid assignment name overrides' {
        $script:Structure.overrides.archetypes.custom = @(@{
            name = 'platform'; type = 'existing'
            policy_assignments_to_add = @('Deploy-This-Name-Is-Too-Long-X')
        })
        { Invoke-SyncFixture | Out-Null } | Should -Throw '*24-char limit*'
        & pwsh -NoLogo -NoProfile -File $script:SyncScriptPath -DefinitionsRootFolder $script:DefinitionsRoot `
            -LibraryPath $script:LibraryRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' `
            -SyncAssignmentsOnly -EnableOverrides 2>&1 | Out-Null
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails the sync when a policy definition cannot be written' {
        $policyDefinition = @{
            name = 'Blocked-Policy'
            properties = @{
                displayName = 'Blocked policy'
                description = 'Write failure fixture'
                metadata = @{ category = 'Blocked' }
            }
        }
        $policyDefinition | ConvertTo-Json -Depth 20 |
            Set-Content (Join-Path $script:LibraryRoot 'platform/alz/policy_definitions/Blocked-Policy.json')
        $blockedPath = Join-Path $script:DefinitionsRoot 'policyDefinitions/ALZ/Blocked'
        $null = New-Item -ItemType Directory -Path (Split-Path $blockedPath) -Force
        'not a directory' | Set-Content $blockedPath
        { Invoke-SyncFixture -AssignmentsOnly:$false | Out-Null } | Should -Throw
    }

    Context 'Private DNS assignments' {
        BeforeEach {
            $script:LibraryAssignment.name = 'Deploy-Private-DNS-Zones'
            $script:LibraryAssignment.properties.policyDefinitionId = '/providers/Microsoft.Authorization/policySetDefinitions/Deploy-Private-DNS-Zones'
            $script:LibraryAssignment.properties.parameters = @{
                azureSiteRecoveryBackupPrivateDnsZoneId = @{ value = '/subscriptions/placeholder/resourceGroups/placeholder/providers/Microsoft.Network/privateDnsZones/privatelink.ne.backup.windowsazure.com' }
            }
            $script:Archetype.policy_assignments = @('Deploy-Private-DNS-Zones')
            $script:AssignmentPath = Join-Path $script:LibraryRoot 'platform/alz/policy_assignments/Deploy-Private-DNS-Zones.alz_policy_assignment.json'
            $script:Structure.defaultParameterValues = @{
                private_dns_zone_region = @{ parameters = @{ value = 'westeurope' } }
                private_dns_zone_subscription_id = @{ parameters = @{ value = '11111111-1111-1111-1111-111111111111' } }
                private_dns_zone_resource_group_name = @{ parameters = @{ value = 'rg-dns' } }
            }
        }

        It 'uses the Backup geo-code <Expected> for <Region>' -TestCases @(
            @{ Region = 'australiasoutheast'; Expected = 'ase' }
            @{ Region = '  AustraliaSoutheast  '; Expected = 'ase' }
            @{ Region = 'ASE'; Expected = 'ase' }
            @{ Region = 'westeurope'; Expected = 'we' }
        ) {
            param($Region, $Expected)
            $script:Structure.defaultParameterValues.private_dns_zone_region.parameters.value = $Region
            Invoke-SyncFixture | Out-Null
            (Read-SyncAssignment).parameters.azureSiteRecoveryBackupPrivateDnsZoneId |
                Should -Be "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.$Expected.backup.windowsazure.com"
        }

        It 'reports an actionable diagnostic for an unknown Backup geo-code' {
            $script:Structure.defaultParameterValues.private_dns_zone_region.parameters.value = 'unknownregion'
            $output = Invoke-SyncFixture 6>&1 | Out-String
            $output | Should -Match 'Unknown Azure Backup region or geo-code'
            $output | Should -Match 'geo-code-list'
        }

        It 'replaces only the Private DNS zone region and preserves unrelated .ne. resource group text' {
            $script:Structure.defaultParameterValues.private_dns_zone_region.parameters.value = 'australiasoutheast'
            $script:Structure.defaultParameterValues.private_dns_zone_resource_group_name.parameters.value = 'dns.ne.prod'
            Invoke-SyncFixture | Out-Null
            (Read-SyncAssignment).parameters.azureSiteRecoveryBackupPrivateDnsZoneId |
                Should -Be '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/dns.ne.prod/providers/Microsoft.Network/privateDnsZones/privatelink.ase.backup.windowsazure.com'
        }

        It 'preserves the library zone name when the optional region is <Kind>' -TestCases @(
            @{ Region = ''; Kind = 'empty' }
            @{ Region = " `t "; Kind = 'whitespace' }
        ) {
            param($Region, $Kind)
            $script:Structure.defaultParameterValues.private_dns_zone_region.parameters.value = $Region
            { Invoke-SyncFixture | Out-Null } | Should -Not -Throw
            (Read-SyncAssignment).parameters.azureSiteRecoveryBackupPrivateDnsZoneId |
                Should -Be '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.ne.backup.windowsazure.com'
        }

        It 'warns and skips Private DNS when the subscription is <Kind>, continuing other assignments' -TestCases @(
            @{ Kind = 'missing' }
            @{ Kind = 'null' }
            @{ Kind = 'empty' }
            @{ Kind = 'whitespace' }
        ) {
            param($Kind)
            if ($Kind -eq 'missing') {
                $script:Structure.defaultParameterValues.Remove('private_dns_zone_subscription_id')
            }
            else {
                $script:Structure.defaultParameterValues.private_dns_zone_subscription_id.parameters.value = switch ($Kind) {
                    'null' { $null }
                    'empty' { '' }
                    'whitespace' { " `t " }
                }
            }
            @{
                name = 'Audit-Control'
                properties = @{
                    displayName = 'Control assignment'
                    description = 'Must still be generated after skipping Private DNS'
                    policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/Control'
                    parameters = @{ effect = @{ value = 'Audit' } }
                }
            } | ConvertTo-Json -Depth 10 |
                Set-Content (Join-Path $script:LibraryRoot 'platform/alz/policy_assignments/Audit-Control.alz_policy_assignment.json')
            $script:Archetype.policy_assignments = @('Deploy-Private-DNS-Zones', 'Audit-Control')
            $output = Invoke-SyncFixture 6>&1 | Out-String
            $output | Should -Match "Skipping assignment 'Deploy-Private-DNS-Zones'.*private_dns_zone_subscription_id is blank"
            $output | Should -Match 'sync completed successfully'
            Test-Path (Join-Path $script:DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Platform/Deploy-Private-DNS-Zones.jsonc') |
                Should -BeFalse
            $control = Get-Content (Join-Path $script:DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Platform/Audit-Control.jsonc') -Raw |
                ConvertFrom-Json
            $control.parameters.effect | Should -Be 'Audit'
        }

        It 'rejects a <Kind> <Parameter> without writing an invalid assignment' -TestCases @(
            @{ Parameter = 'private_dns_zone_resource_group_name'; Kind = 'missing' }
            @{ Parameter = 'private_dns_zone_resource_group_name'; Kind = 'null' }
            @{ Parameter = 'private_dns_zone_resource_group_name'; Kind = 'empty' }
            @{ Parameter = 'private_dns_zone_resource_group_name'; Kind = 'whitespace' }
        ) {
            param($Parameter, $Kind)
            if ($Kind -eq 'missing') {
                $script:Structure.defaultParameterValues.Remove($Parameter)
            }
            else {
                $script:Structure.defaultParameterValues[$Parameter].parameters.value = switch ($Kind) {
                    'null' { $null }
                    'empty' { '' }
                    'whitespace' { " `t " }
                }
            }
            { Invoke-SyncFixture | Out-Null } | Should -Throw "*$Parameter is required*"
            Test-Path (Join-Path $script:DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Platform/Deploy-Private-DNS-Zones.jsonc') |
                Should -BeFalse
        }
    }

    It 'omits unset optional properties from <Name> and preserves populated values' -TestCases @(
        @{ Name = 'Deploy-VM-ChangeTrack' }
        @{ Name = 'Deploy-Private-DNS-Zones' }
    ) {
        param($Name)
        $script:LibraryAssignment.name = $Name
        $script:Archetype.policy_assignments = @($Name)
        $script:AssignmentPath = Join-Path $script:LibraryRoot "platform/alz/policy_assignments/$Name.alz_policy_assignment.json"
        if ($Name -eq 'Deploy-Private-DNS-Zones') {
            $script:LibraryAssignment.properties.parameters = @{
                backupDnsZoneId = @{ value = 'privatelink.ne.backup.windowsazure.com' }
            }
            $script:Structure.defaultParameterValues = @{
                private_dns_zone_region = @{ parameters = @{ value = 'westeurope' } }
                private_dns_zone_subscription_id = @{ parameters = @{ value = '11111111-1111-1111-1111-111111111111' } }
                private_dns_zone_resource_group_name = @{ parameters = @{ value = 'rg-dns' } }
            }
        }
        $script:LibraryAssignment.properties.definitionVersion = $null
        $script:LibraryAssignment.properties.nonComplianceMessages = $null
        Invoke-SyncFixture | Out-Null
        $assignment = Read-SyncAssignment
        $assignment.PSObject.Properties.Name | Should -Not -Contain 'definitionVersion'
        $assignment.PSObject.Properties.Name | Should -Not -Contain 'nonComplianceMessages'
        $script:LibraryAssignment.properties.definitionVersion = '2.*.*'
        $script:LibraryAssignment.properties.nonComplianceMessages = @(@{ message = 'Resources {enforcementMode} comply.' })
        Invoke-SyncFixture | Out-Null
        $assignment = Read-SyncAssignment
        $assignment.definitionVersion | Should -Be '2.*.*'
        $assignment.nonComplianceMessages[0].message | Should -Be 'Resources must comply.'
    }

    Context 'Owned temporary clones' {
        BeforeEach {
            $script:ClonePaths = [System.Collections.Generic.List[string]]::new()
            $global:EPACSyncTestCloneState = @{
                Paths = $script:ClonePaths
                Source = $script:LibraryRoot
                Failure = ''
            }
            Write-SyncFixture
            Mock git {
                param($Arguments)
                if ($Arguments[0] -eq '-C') {
                    $global:LASTEXITCODE = 1
                    return
                }
                $destination = $Arguments[-1]
                $global:EPACSyncTestCloneState.Paths.Add($destination)
                $null = New-Item -ItemType Directory -Path $destination -Force
                Copy-Item (Join-Path $global:EPACSyncTestCloneState.Source '*') $destination -Recurse
                $global:LASTEXITCODE = $global:EPACSyncTestCloneState.Failure -eq 'clone' ? 1 : 0
            }
        }

        AfterEach {
            Remove-Variable -Name EPACSyncTestCloneState -Scope Global
        }

        It 'preserves existing temp directories and removes its clone on <Stage>' -TestCases @(
            @{ Stage = 'success' }
            @{ Stage = 'clone' }
            @{ Stage = 'sync' }
            @{ Stage = 'structure' }
        ) {
            param($Stage)
            $global:EPACSyncTestCloneState.Failure = $Stage
            $marker = Join-Path $script:CaseRoot 'temp/marker.txt'
            $null = New-Item -ItemType Directory -Path (Split-Path $marker) -Force
            'caller-owned content' | Set-Content $marker
            if ($Stage -eq 'sync') {
                $script:Structure.overrides.archetypes.custom = @(@{
                    name = 'platform'; type = 'existing'
                    policy_assignments_to_add = @('Deploy-This-Name-Is-Too-Long-X')
                })
                Write-SyncFixture
            }
            if ($Stage -eq 'structure') {
                Remove-Item $script:StructurePath
            }
            Push-Location $script:CaseRoot
            try {
                $invoke = {
                    & $script:SyncScriptPath -DefinitionsRootFolder $script:DefinitionsRoot -Type ALZ `
                        -PacEnvironmentSelector 'epac-dev' -SyncAssignmentsOnly -EnableOverrides | Out-Null
                }
                if ($Stage -eq 'success') { & $invoke }
                else { $invoke | Should -Throw }
            }
            finally { Pop-Location }
            Get-Content $marker -Raw | Should -Match 'caller-owned content'
            $script:ClonePaths | Should -HaveCount 1
            Test-Path $script:ClonePaths[0] | Should -BeFalse
            Test-Path $script:LibraryRoot | Should -BeTrue
        }

        It 'cleans an AMBA extended clone when sparse checkout fails and preserves the supplied library' {
            {
                & $script:SyncScriptPath -DefinitionsRootFolder $script:DefinitionsRoot -LibraryPath $script:LibraryRoot `
                    -Type AMBA -PacEnvironmentSelector 'epac-dev' -SyncAMBAExtendedPolicies | Out-Null
            } | Should -Throw '*Failed to check out AMBA extended policy services*'
            $script:ClonePaths | Should -HaveCount 1
            Test-Path $script:ClonePaths[0] | Should -BeFalse
            Test-Path $script:LibraryRoot | Should -BeTrue
        }
    }
}
