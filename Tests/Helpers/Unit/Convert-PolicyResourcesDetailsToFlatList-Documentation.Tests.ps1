BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-PolicyResourceProperties.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-DeepCloneAsOrderedHashtable.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Convert-EffectToCsvString.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Convert-EffectToOrdinal.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Convert-PolicyResourcesDetailsToFlatList-Documentation.ps1')

    function Get-TestAssignment {
        param (
            [string] $ReferenceId
        )

        return @{
            properties = @{
                parameters = @{}
                overrides  = @(
                    @{
                        kind      = 'policyEffect'
                        value     = 'disabled'
                        selectors = @(
                            @{
                                kind = 'policyDefinitionReferenceId'
                                in   = @($ReferenceId)
                            }
                        )
                    }
                )
            }
        }
    }

    function Get-TestPolicyDetail {
        param (
            [string] $ReferenceId
        )

        return @{
            id                          = '/providers/Microsoft.Authorization/policyDefinitions/test-policy'
            name                        = 'test-policy'
            displayName                 = 'Test policy'
            description                 = 'Test policy description'
            policyType                  = 'Custom'
            category                    = 'Test'
            version                     = '1.0.0'
            isDeprecated                = $false
            policyDefinitionReferenceId = $ReferenceId
            effectParameterName         = 'effect'
            effectValue                 = 'audit'
            effectDefault               = 'audit'
            effectAllowedValues         = @('Audit', 'Disabled')
            effectAllowedOverrides      = @('Audit', 'Disabled')
            effectReason                = 'PolicySet Default'
            parameters                  = @{}
            groupNames                  = @()
        }
    }
}

Describe 'Convert-PolicyResourcesDetailsToFlatList-Documentation' {
    It 'canonicalizes a lowercase override for a standalone policy assignment' {
        $referenceId = 'standalone-reference'
        $itemId = '/providers/Microsoft.Authorization/policyAssignments/test-assignment'
        $policyDetail = Get-TestPolicyDetail -ReferenceId $referenceId
        $policyDetail.policyDefinitionId = $policyDetail.id
        $policyDetail.assignmentId = $itemId
        $policyDetail.assignment = Get-TestAssignment -ReferenceId $referenceId
        $policyDetail.policiesWithMultipleReferenceIds = @{}
        $policyDetail.policyDefinitions = @()

        $result = Convert-PolicyResourcesDetailsToFlatList-Documentation `
            -ItemList @(@{
                    shortName    = 'assignment'
                    itemId       = $itemId
                    assignmentId = $itemId
                }) `
            -Details @{$itemId = $policyDetail }

        $entry = $result[$policyDetail.id]
        $entry.effectValue | Should -Be 'Disabled'
        $entry.policySetEffectStrings | Should -Be @('assignment: Disabled (override)')
    }

    It 'canonicalizes a lowercase override for a policy set assignment' {
        $referenceId = 'policy-set-reference'
        $itemId = '/providers/Microsoft.Authorization/policyAssignments/test-set-assignment'
        $policyDetail = Get-TestPolicyDetail -ReferenceId $referenceId
        $detail = @{
            id                                = '/providers/Microsoft.Authorization/policySetDefinitions/test-set'
            name                              = 'test-set'
            displayName                       = 'Test policy set'
            description                       = 'Test policy set description'
            policyType                        = 'Custom'
            assignmentId                      = $itemId
            assignment                        = Get-TestAssignment -ReferenceId $referenceId
            policiesWithMultipleReferenceIds  = @{}
            policyDefinitions                 = @($policyDetail)
        }

        $result = Convert-PolicyResourcesDetailsToFlatList-Documentation `
            -ItemList @(@{
                    shortName    = 'assignment'
                    itemId       = $itemId
                    policySetId  = $detail.id
                    assignmentId = $itemId
                }) `
            -Details @{$itemId = $detail }

        $entry = $result[$policyDetail.id]
        $entry.effectValue | Should -Be 'Disabled'
        $entry.policySetEffectStrings | Should -Be @('assignment: Disabled (override)')
    }

    It 'canonicalizes lowercase default effects in policy set summaries' {
        $referenceId = 'default-reference'
        $itemId = '/providers/Microsoft.Authorization/policySetDefinitions/test-set'
        $policyDetail = Get-TestPolicyDetail -ReferenceId $referenceId
        $detail = @{
            id                               = $itemId
            name                             = 'test-set'
            displayName                      = 'Test policy set'
            description                      = 'Test policy set description'
            policyType                       = 'Custom'
            policiesWithMultipleReferenceIds = @{}
            policyDefinitions                = @($policyDetail)
        }

        $result = Convert-PolicyResourcesDetailsToFlatList-Documentation `
            -ItemList @(@{
                    shortName   = 'policy-set'
                    itemId      = $itemId
                    policySetId = $itemId
                }) `
            -Details @{$itemId = $detail }

        $entry = $result[$policyDetail.id]
        $entry.effectValue | Should -Be 'Audit'
        $entry.policySetEffectStrings | Should -Be @('policy-set: Audit (default: effect)')
    }
}
