BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-ConditionalEffectValue.ps1')

    $script:expression = "[if(contains(parameters('resourceTypeList'),'microsoft.keyvault/vaults'),parameters('effect'),'Disabled')]"
    $script:policySetParameters = @{
        effect           = @{ defaultValue = 'DeployIfNotExists' }
        resourceTypeList = @{ defaultValue = @('microsoft.keyvault/vaults', 'microsoft.cache/redis') }
    }
}

Describe 'Get-ConditionalEffectValue' {
    It 'uses the Policy Set defaults' {
        Get-ConditionalEffectValue -EffectExpression $script:expression -PolicySetParameters $script:policySetParameters -AssignmentParameters @{} |
            Should -Be 'DeployIfNotExists'
    }

    It 'uses the Assignment parameters before the defaults' {
        $assignmentParameters = @{ effect = @{ value = 'AuditIfNotExists' }; resourceTypeList = @{ value = 'microsoft.keyvault/vaults' } }
        Get-ConditionalEffectValue -EffectExpression $script:expression -PolicySetParameters $script:policySetParameters -AssignmentParameters $assignmentParameters |
            Should -Be 'AuditIfNotExists'
    }

    It 'uses the second result when the list does not contain the item' {
        $assignmentParameters = @{ resourceTypeList = @{ value = @('microsoft.cache/redis', 'Microsoft.KeyVault/vaults') } }
        Get-ConditionalEffectValue -EffectExpression $script:expression -PolicySetParameters $script:policySetParameters -AssignmentParameters $assignmentParameters |
            Should -Be 'Disabled'
    }

    It 'does not depend on parameter names or result order' {
        $expression = "[if(contains(parameters('excludedKinds'), 'functionapp'), 'Disabled', parameters('auditEffect'))]"
        $policySetParameters = @{ excludedKinds = @{ defaultValue = @() }; auditEffect = @{ defaultValue = 'Audit' } }
        Get-ConditionalEffectValue -EffectExpression $expression -PolicySetParameters $policySetParameters -AssignmentParameters @{} |
            Should -Be 'Audit'
    }

    It 'returns null for <Name>' -ForEach @(
        @{ Name = 'an effect'; Value = 'Audit'; Parameters = $null }
        @{ Name = 'a parameter reference'; Value = "[parameters('effect')]"; Parameters = $null }
        @{ Name = 'a parameter without value'; Value = $null; Parameters = @{ resourceTypeList = @{ defaultValue = @('microsoft.keyvault/vaults') }; effect = @{} } }
    ) {
        $expression = if ($null -ne $Value) { $Value } else { $script:expression }
        $policySetParameters = if ($null -ne $Parameters) { $Parameters } else { $script:policySetParameters }
        Get-ConditionalEffectValue -EffectExpression $expression -PolicySetParameters $policySetParameters -AssignmentParameters @{} |
            Should -BeNullOrEmpty
    }
}
