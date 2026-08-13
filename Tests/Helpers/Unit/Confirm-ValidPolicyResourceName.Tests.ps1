BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-ValidPolicyResourceName.ps1')
}

Describe 'Confirm-ValidPolicyResourceName' {
    It 'accepts a valid policy resource name' {
        Confirm-ValidPolicyResourceName -Name 'policy.resource_name-(1)' | Should -BeTrue
    }

    It 'rejects the invalid character <Character>' -ForEach @(
        @{ Character = '%' }
        @{ Character = '&' }
        @{ Character = '\' }
        @{ Character = '?' }
        @{ Character = '/' }
        @{ Character = '<' }
        @{ Character = '>' }
        @{ Character = ':' }
        @{ Character = '#' }
        @{ Character = '*' }
        @{ Character = '+' }
    ) {
        Confirm-ValidPolicyResourceName -Name "policy${Character}name" | Should -BeFalse
    }

    It 'rejects control characters' {
        Confirm-ValidPolicyResourceName -Name "policy`nname" | Should -BeFalse
    }

    It 'rejects a trailing space' {
        Confirm-ValidPolicyResourceName -Name 'policy-name ' | Should -BeFalse
    }
}

Describe 'Assert-ValidPolicyResourceName' {
    It 'throws a clear error for an invalid resource name' {
        {
            Assert-ValidPolicyResourceName -Name 'exempt-kv-delete-#protect' -ResourceType 'Policy exemption'
        } | Should -Throw "*Policy exemption name 'exempt-kv-delete-#protect'*#*"
    }
}
