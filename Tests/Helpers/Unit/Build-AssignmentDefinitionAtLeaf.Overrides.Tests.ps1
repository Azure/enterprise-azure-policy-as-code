[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Variables are set to check they do not leak into Build-AssignmentDefinitionAtLeaf')]
param()

BeforeAll {
    foreach ($helper in @(
            'Confirm-ValidPolicyResourceName.ps1'
            'Get-DeepCloneAsOrderedHashtable.ps1'
            'Build-AssignmentParameterObject.ps1'
            'Confirm-ObjectValueEqualityDeep.ps1'
            'Build-AssignmentDefinitionAtLeaf.ps1'
        )) {
        . (Join-Path $PSScriptRoot "../../../Scripts/Helpers/$helper")
    }

    $script:testPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/test-policy'

    function New-LeafDefinition {
        param (
            $Overrides
        )
        @{
            nodeName            = '/root/test'
            assignment          = @{ name = 'override-test'; displayName = 'Test'; description = '' }
            definitionEntryList = @(
                @{
                    policyDefinitionId = $script:testPolicyId
                    isPolicySet        = $false
                    assignment         = @{ append = $false; name = ''; displayName = ''; description = '' }
                }
            )
            scopeCollection     = @( @{ scope = '/providers/Microsoft.Management/managementGroups/test-mg' } )
            metadata            = @{}
            parameters          = @{}
            enforcementMode     = 'Default'
            overrides           = $Overrides
        }
    }

    function Invoke-Leaf {
        param (
            [hashtable] $AssignmentDefinition
        )
        $combinedPolicyDetails = @{
            policies   = @{
                $script:testPolicyId = @{
                    name                   = 'test-policy'
                    effectAllowedOverrides = @( 'Audit', 'Deny', 'Disabled' )
                    parameters             = @{}
                }
            }
            policySets = @{}
        }
        Build-AssignmentDefinitionAtLeaf `
            -PacEnvironment @{ pacOwnerId = 'test'; deployedBy = 'test' } `
            -AssignmentDefinition $AssignmentDefinition `
            -CombinedPolicyDetails $combinedPolicyDetails `
            -PolicyRoleIds @{} `
            -RoleDefinitions @{}
    }
}

Describe 'Build-AssignmentDefinitionAtLeaf overrides for a single Policy definitionEntry' {

    It 'applies an override which does not name the Policy' {
        $hasErrors, $assignmentsList = Invoke-Leaf -AssignmentDefinition (New-LeafDefinition -Overrides @(
                @{ kind = 'policyEffect'; value = 'Deny' }
            ))
        $hasErrors | Should -BeFalse
        $assignmentsList[0].overrides[0].value | Should -Be 'Deny'
    }

    It 'rejects an override which names the Policy with <Property>' -ForEach @(
        @{ Property = 'policyName'; Value = 'test-policy' }
        @{ Property = 'policyId'; Value = '/providers/Microsoft.Authorization/policyDefinitions/test-policy' }
    ) {
        Mock Write-Error {}
        $hasErrors, $null = Invoke-Leaf -AssignmentDefinition (New-LeafDefinition -Overrides @(
                @{ kind = 'policyEffect'; value = 'Deny'; $Property = $Value }
            ))
        $hasErrors | Should -BeTrue
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
            $Message -like '*overrides must NOT specify which Policy for a single definitionEntry*'
        }
    }

    It 'ignores policySetName and policySetId variables in the calling scope' {
        # The check used to read $policySetName and $policySetId, which are never set for a Policy
        # definitionEntry, so a caller's variables of the same name leaked in.
        $policySetName = 'some-policy-set'
        $policySetId = '/providers/Microsoft.Authorization/policySetDefinitions/some-policy-set'
        $hasErrors, $assignmentsList = Invoke-Leaf -AssignmentDefinition (New-LeafDefinition -Overrides @(
                @{ kind = 'policyEffect'; value = 'Deny' }
            ))
        $hasErrors | Should -BeFalse
        $assignmentsList[0].overrides[0].value | Should -Be 'Deny'
    }
}
