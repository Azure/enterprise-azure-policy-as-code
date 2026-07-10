BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Compare-SemanticVersion.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-BestMatchingVersion.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-PolicyResourceProperties.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-CalculatedPolicyAssignmentsAndReferenceIds.ps1')

    $script:policySetId = '/providers/Microsoft.Authorization/policySetDefinitions/e3ec7e09-768c-4b64-882c-fcada3772047'

    # Latest version (1.4.0-preview) has removed policy 'polB' / reference 'refB'
    # Pinned version (1.3.0-preview) still contains 'polB' / reference 'refB'
    $script:combinedPolicyDetails = @{
        policies          = @{}
        policySets        = @{
            $script:policySetId = @{
                id                = $script:policySetId
                policyDefinitions = @(
                    @{ id = 'polA'; policyDefinitionReferenceId = 'refA' }
                )
            }
        }
        policySetVersions = @{
            "$($script:policySetId)||1.3.0-preview" = @{
                id                = $script:policySetId
                policyDefinitions = @(
                    @{ id = 'polA'; policyDefinitionReferenceId = 'refA' }
                    @{ id = 'polB'; policyDefinitionReferenceId = 'refB' }
                )
            }
        }
    }

    function New-TestAssignment {
        param (
            [string] $Name,
            [string] $DefinitionVersion
        )
        $properties = @{
            policyDefinitionId = $script:policySetId
            displayName        = $Name
            notScopes          = @()
        }
        if (-not [string]::IsNullOrWhiteSpace($DefinitionVersion)) {
            $properties.definitionVersion = $DefinitionVersion
        }
        return @{
            id         = "/providers/Microsoft.Management/managementGroups/epac-dev/providers/Microsoft.Authorization/policyAssignments/$Name"
            name       = $Name
            scope      = '/providers/Microsoft.Management/managementGroups/epac-dev'
            properties = $properties
        }
    }
}

Describe 'Get-CalculatedPolicyAssignmentsAndReferenceIds version resolution' {
    It 'resolves referenceIds from the pinned version when an assignment pins an older version' {
        $assignment = New-TestAssignment -Name 'pinned' -DefinitionVersion '1.3.*-preview'
        $result = Get-CalculatedPolicyAssignmentsAndReferenceIds `
            -Assignments @($assignment) `
            -CombinedPolicyDetails $script:combinedPolicyDetails

        $calculated = $result.byPolicySetIdCalculatedAssignments.$script:policySetId[0]
        $calculated.policyDefinitionReferenceIds | Should -Contain 'refA'
        $calculated.policyDefinitionReferenceIds | Should -Contain 'refB'
    }

    It 'uses the latest version when the assignment does not pin a version' {
        $assignment = New-TestAssignment -Name 'unpinned' -DefinitionVersion $null
        $result = Get-CalculatedPolicyAssignmentsAndReferenceIds `
            -Assignments @($assignment) `
            -CombinedPolicyDetails $script:combinedPolicyDetails

        $calculated = $result.byPolicySetIdCalculatedAssignments.$script:policySetId[0]
        $calculated.policyDefinitionReferenceIds | Should -Contain 'refA'
        $calculated.policyDefinitionReferenceIds | Should -Not -Contain 'refB'
    }

    It 'falls back to the latest version when no matching version is collected' {
        $assignment = New-TestAssignment -Name 'nomatch' -DefinitionVersion '2.0.*'
        $result = Get-CalculatedPolicyAssignmentsAndReferenceIds `
            -Assignments @($assignment) `
            -CombinedPolicyDetails $script:combinedPolicyDetails

        $calculated = $result.byPolicySetIdCalculatedAssignments.$script:policySetId[0]
        $calculated.policyDefinitionReferenceIds | Should -Contain 'refA'
        $calculated.policyDefinitionReferenceIds | Should -Not -Contain 'refB'
    }
}
