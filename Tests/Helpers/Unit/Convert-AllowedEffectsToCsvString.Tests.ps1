BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Convert-AllowedEffectsToCsvString.ps1')
}

Describe 'Convert-AllowedEffectsToCsvString' {
    It 'returns the none prefix text when no effects are allowed' {
        {
            Convert-AllowedEffectsToCsvString `
                -DefaultEffect $null `
                -IsEffectParameterized $false `
                -EffectAllowedValues @() `
                -EffectAllowedOverrides @() `
                -InCellSeparator1 ': ' `
                -InCellSeparator2 ','
        } | Should -Not -Throw

        $result = Convert-AllowedEffectsToCsvString `
            -DefaultEffect $null `
            -IsEffectParameterized $false `
            -EffectAllowedValues @() `
            -EffectAllowedOverrides @() `
            -InCellSeparator1 ': ' `
            -InCellSeparator2 ','

        $result | Should -Be 'none: No effect allowed,Error'
    }

    It 'returns sorted parameterized effects' {
        $result = Convert-AllowedEffectsToCsvString `
            -DefaultEffect $null `
            -IsEffectParameterized $true `
            -EffectAllowedValues @('Audit', 'Deny') `
            -EffectAllowedOverrides @() `
            -InCellSeparator1 ': ' `
            -InCellSeparator2 ','

        $result | Should -Be 'parameter: Deny,Audit'
    }
}
