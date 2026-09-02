BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-FilteredPolicySetRoleDefinitionIds.ps1')

    $script:policySetId = '/providers/Microsoft.Authorization/policySetDefinitions/test-set'
    $script:eventHubRole = '/providers/Microsoft.Authorization/roleDefinitions/f526a384-b230-433a-b45c-95f59c4a2dec'
    $script:laRole = '/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
    $script:uaaRole = '/providers/Microsoft.Authorization/roleDefinitions/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'

    $script:pinnedPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/pinned'
    $script:openPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/open'

    function New-Member {
        param (
            [string] $PolicyId,
            [string] $ReferenceId,
            [string] $EffectReason,
            [string] $EffectValue
        )
        @{
            id                          = $PolicyId
            policyDefinitionReferenceId = $ReferenceId
            effectReason                = $EffectReason
            effectValue                 = $EffectValue
        }
    }

    function New-Override {
        param (
            [string] $Value,
            [string[]] $In,
            [string[]] $NotIn,
            [switch] $NoSelectors
        )
        $override = @{
            kind  = 'policyEffect'
            value = $Value
        }
        if (-not $NoSelectors) {
            $selector = @{ kind = 'policyDefinitionReferenceId' }
            if ($In) { $selector.in = $In }
            if ($NotIn) { $selector.notIn = $NotIn }
            $override.selectors = @( $selector )
        }
        $override
    }
}

Describe 'Get-FilteredPolicySetRoleDefinitionIds' {

    Context 'members whose pinned effect is not a recognised non-deploying literal' {

        BeforeEach {
            $script:policyRoleIds = @{
                $script:policySetId    = @( $script:eventHubRole )
                $script:pinnedPolicyId = @( $script:eventHubRole )
            }
        }

        It 'keeps roles when the Policy Set pins the effect to an ARM expression' {
            # Built-in diagnostic settings Policy Sets pin member effects to an expression which
            # evaluates to parameters('effect'), defaulting to DeployIfNotExists, so the roles are
            # genuinely required. Convert-PolicySetToDetails still reports these as PolicySet Fixed.
            $armExpression = "[if(contains(parameters('resourceTypeList'),'microsoft.aad/domainservices'),parameters('effect'),'Disabled')]"
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'expressionRef' -EffectReason 'PolicySet Fixed' -EffectValue $armExpression
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @()

            $result | Should -Be @( $script:eventHubRole )
        }

        It 'keeps roles when the pinned effect is an unrecognised value' {
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'unknownRef' -EffectReason 'PolicySet Fixed' -EffectValue 'SomeFutureEffect'
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @()

            $result | Should -Be @( $script:eventHubRole )
        }

        It 'removes roles for every recognised non-deploying literal' -ForEach @(
            @{ Effect = 'Audit' }
            @{ Effect = 'AuditIfNotExists' }
            @{ Effect = 'Deny' }
            @{ Effect = 'DenyAction' }
            @{ Effect = 'Disabled' }
            @{ Effect = 'Append' }
            @{ Effect = 'Manual' }
            @{ Effect = 'AddToNetworkGroup' }
            @{ Effect = 'auditifnotexists' }
        ) {
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'pinnedRef' -EffectReason 'PolicySet Fixed' -EffectValue $Effect
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @()

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'members pinned by the Policy Set to a non-deploying effect' {

        BeforeEach {
            $script:policyRoleIds = @{
                $script:policySetId   = @( $script:eventHubRole )
                $script:pinnedPolicyId = @( $script:eventHubRole )
            }
            $script:policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'pinnedRef' -EffectReason 'PolicySet Fixed' -EffectValue 'AuditIfNotExists'
                )
            }
        }

        It 'removes roles only contributed by the pinned member' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @()

            $result | Should -BeNullOrEmpty
        }

        It 'keeps the role when an in selector override raises the member to DeployIfNotExists' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @( (New-Override -Value 'DeployIfNotExists' -In @('pinnedRef')) )

            $result | Should -Be @( $script:eventHubRole )
        }

        It 'keeps the role when a notIn selector override leaves the member raised' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @( (New-Override -Value 'Modify' -NotIn @('someOtherRef')) )

            $result | Should -Be @( $script:eventHubRole )
        }

        It 'removes the role when a notIn selector override excludes the member' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @( (New-Override -Value 'DeployIfNotExists' -NotIn @('pinnedRef')) )

            $result | Should -BeNullOrEmpty
        }

        It 'removes the role when the override targets a different member' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @( (New-Override -Value 'DeployIfNotExists' -In @('unrelatedRef')) )

            $result | Should -BeNullOrEmpty
        }

        It 'removes the role when the override sets a non-deploying effect' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @( (New-Override -Value 'Disabled' -In @('pinnedRef')) )

            $result | Should -BeNullOrEmpty
        }

        It 'never treats Manual as a deploying effect' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @( (New-Override -Value 'Manual' -In @('pinnedRef')) )

            $result | Should -BeNullOrEmpty
        }

        It 'keeps every role when a deploying override cannot be attributed to a member' {
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $script:policySetDetails `
                -PolicyRoleIds $script:policyRoleIds `
                -OverridesList @( (New-Override -Value 'DeployIfNotExists' -NoSelectors) )

            $result | Should -Be @( $script:eventHubRole )
        }
    }

    Context 'members which are not pinned to a non-deploying effect' {

        It 'keeps roles when the Policy Set pins a deploying effect' {
            $policyRoleIds = @{
                $script:policySetId    = @( $script:eventHubRole )
                $script:pinnedPolicyId = @( $script:eventHubRole )
            }
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'pinnedRef' -EffectReason 'PolicySet Fixed' -EffectValue 'DeployIfNotExists'
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $policyRoleIds `
                -OverridesList @()

            $result | Should -Be @( $script:eventHubRole )
        }

        It 'keeps roles when the effect is parameterized by the Policy Set' {
            $policyRoleIds = @{
                $script:policySetId  = @( $script:laRole )
                $script:openPolicyId = @( $script:laRole )
            }
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:openPolicyId -ReferenceId 'openRef' -EffectReason 'PolicySet Default' -EffectValue 'AuditIfNotExists'
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $policyRoleIds `
                -OverridesList @()

            $result | Should -Be @( $script:laRole )
        }
    }

    Context 'roles contributed by more than one member' {

        It 'keeps a role which a non-pinned member also contributes' {
            $policyRoleIds = @{
                $script:policySetId    = @( $script:laRole, $script:eventHubRole )
                $script:pinnedPolicyId = @( $script:laRole, $script:eventHubRole )
                $script:openPolicyId   = @( $script:laRole )
            }
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'pinnedRef' -EffectReason 'PolicySet Fixed' -EffectValue 'AuditIfNotExists'
                    New-Member -PolicyId $script:openPolicyId -ReferenceId 'openRef' -EffectReason 'PolicySet Default' -EffectValue 'AuditIfNotExists'
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $policyRoleIds `
                -OverridesList @()

            $result | Should -Be @( $script:laRole )
        }

        It 'keeps a role which another pinned but overridden member contributes' {
            $secondPinnedPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/pinned2'
            $policyRoleIds = @{
                $script:policySetId    = @( $script:uaaRole, $script:eventHubRole )
                $script:pinnedPolicyId = @( $script:uaaRole )
                $secondPinnedPolicyId  = @( $script:uaaRole, $script:eventHubRole )
            }
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'pinnedRef' -EffectReason 'PolicySet Fixed' -EffectValue 'AuditIfNotExists'
                    New-Member -PolicyId $secondPinnedPolicyId -ReferenceId 'pinnedRef2' -EffectReason 'PolicySet Fixed' -EffectValue 'AuditIfNotExists'
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $policyRoleIds `
                -OverridesList @( (New-Override -Value 'DeployIfNotExists' -In @('pinnedRef')) )

            # pinnedRef is raised so uaaRole is required; eventHubRole is only required by the
            # still pinned pinnedRef2 and is removed.
            $result | Should -Be @( $script:uaaRole )
        }
    }

    Context 'safety fallbacks' {

        It 'returns the unfiltered union when the Policy Set has no roles' {
            $policyRoleIds = @{}
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails @{ policyDefinitions = @() } `
                -PolicyRoleIds $policyRoleIds `
                -OverridesList @()

            $result | Should -BeNullOrEmpty
        }

        It 'returns the unfiltered union when no Policy Set details are available' {
            $policyRoleIds = @{ $script:policySetId = @( $script:eventHubRole ) }
            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $null `
                -PolicyRoleIds $policyRoleIds `
                -OverridesList @()

            $result | Should -Be @( $script:eventHubRole )
        }

        It 'keeps a role which cannot be attributed to any member' {
            $policyRoleIds = @{
                $script:policySetId    = @( $script:eventHubRole, $script:laRole )
                $script:pinnedPolicyId = @( $script:eventHubRole )
            }
            $policySetDetails = @{
                policyDefinitions = @(
                    New-Member -PolicyId $script:pinnedPolicyId -ReferenceId 'pinnedRef' -EffectReason 'PolicySet Fixed' -EffectValue 'AuditIfNotExists'
                )
            }

            $result = Get-FilteredPolicySetRoleDefinitionIds `
                -PolicySetId $script:policySetId `
                -PolicySetDetails $policySetDetails `
                -PolicyRoleIds $policyRoleIds `
                -OverridesList @()

            $result | Should -Be @( $script:laRole )
        }
    }
}
