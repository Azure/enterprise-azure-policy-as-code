BeforeAll {
    $restMethodsPath = Join-Path $PSScriptRoot '../../../Scripts/Helpers/RestMethods'
    . (Join-Path $restMethodsPath 'ConvertTo-AzPolicyRestPath.ps1')
    . (Join-Path $restMethodsPath 'Get-AzPolicyAssignmentRestMethod.ps1')
    . (Join-Path $restMethodsPath 'Remove-AzResourceByIdRestMethod.ps1')
    . (Join-Path $restMethodsPath 'Set-AzPolicyAssignmentRestMethod.ps1')
    . (Join-Path $restMethodsPath 'Set-AzPolicyDefinitionRestMethod.ps1')
    . (Join-Path $restMethodsPath 'Set-AzPolicyExemptionRestMethod.ps1')
    . (Join-Path $restMethodsPath 'Set-AzPolicySetDefinitionRestMethod.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-ValidPolicyResourceName.ps1')

    function Get-DeepCloneAsOrderedHashtable {}
    function Remove-NullFields {}
    function Write-ModernStatus {}
}

Describe 'ConvertTo-AzPolicyRestPath' {
    It 'encodes reserved characters in a policy assignment name' {
        $id = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/CApp_NoPubIng-#5030-test'

        ConvertTo-AzPolicyRestPath -Id $id |
            Should -Be '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/CApp_NoPubIng-%235030-test'
    }

    It 'encodes a provider-level policy resource name' {
        $id = '/providers/Microsoft.Authorization/policyAssignments/assignment-#1'

        ConvertTo-AzPolicyRestPath -Id $id |
            Should -Be '/providers/Microsoft.Authorization/policyAssignments/assignment-%231'
    }

    It 'encodes reserved characters in a policy exemption name' {
        $id = '/providers/Microsoft.Management/managementGroups/test/providers/Microsoft.Authorization/policyExemptions/exemption?#1'

        ConvertTo-AzPolicyRestPath -Id $id |
            Should -Be '/providers/Microsoft.Management/managementGroups/test/providers/Microsoft.Authorization/policyExemptions/exemption%3F%231'
    }

    It 'does not double encode an encoded policy resource name' {
        $id = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/assignment-%235030'

        ConvertTo-AzPolicyRestPath -Id $id | Should -Be $id
    }

    It 'does not change other resource types' {
        $id = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/policy-#1'

        ConvertTo-AzPolicyRestPath -Id $id | Should -Be $id
    }
}

Describe 'Policy assignment REST paths' {
    BeforeEach {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{}'
            }
        }
        Mock Write-ModernStatus
        Mock Get-DeepCloneAsOrderedHashtable { [ordered]@{} }
    }

    It 'encodes the assignment name for GET requests' {
        $id = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/assignment-#1'

        Get-AzPolicyAssignmentRestMethod -AssignmentId $id -ApiVersion '2025-03-01'

        Should -Invoke Invoke-AzRestMethod -ParameterFilter {
            $Path -eq "$($id.Replace('#', '%23'))?api-version=2025-03-01" -and $Method -eq 'GET'
        }
    }

    It 'encodes the assignment name for PUT requests' {
        $assignment = @{
            id               = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/assignment-#1'
            name             = 'assignment-1'
            displayName      = 'Assignment'
            parameters       = @{}
            identityRequired = $false
        }

        Set-AzPolicyAssignmentRestMethod -AssignmentObj $assignment -ApiVersion '2025-03-01'

        Should -Invoke Invoke-AzRestMethod -ParameterFilter {
            $Path -eq "$($assignment.id.Replace('#', '%23'))?api-version=2025-03-01" -and $Method -eq 'PUT'
        }
    }
}

Describe 'Policy exemption REST paths' {
    BeforeEach {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{}'
            }
        }
        Mock Remove-NullFields
        Mock Write-ModernStatus
    }

    It 'encodes the exemption name for PUT requests' {
        $exemption = @{
            id    = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyExemptions/exemption-#1'
            name  = 'exemption-1'
            scope = '/subscriptions/00000000-0000-0000-0000-000000000000'
        }

        Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption -ApiVersion '2022-07-01-preview'

        Should -Invoke Invoke-AzRestMethod -ParameterFilter {
            $Path -eq "$($exemption.id.Replace('#', '%23'))?api-version=2022-07-01-preview" -and $Method -eq 'PUT'
        }
    }
}

Describe 'Policy resource DELETE paths' {
    BeforeEach {
        Mock Invoke-AzRestMethod {
            [pscustomobject]@{
                StatusCode = 200
                Content    = '{}'
            }
        }

        Mock Write-ModernStatus
    }

    It 'encodes policy assignment names' {
        $id = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyAssignments/assignment-#1'

        Remove-AzResourceByIdRestMethod -Id $id -ApiVersion '2025-03-01'

        Should -Invoke Invoke-AzRestMethod -ParameterFilter {
            $Path -eq "$($id.Replace('#', '%23'))?api-version=2025-03-01" -and $Method -eq 'DELETE'
        }
    }

    Describe 'Policy REST resource name validation' {
        BeforeEach {
            Mock Invoke-AzRestMethod
        }

        It 'rejects an invalid policy definition name before the REST call' {
            $definition = [pscustomobject]@{ name = 'policy#name' }

            { Set-AzPolicyDefinitionRestMethod -DefinitionObj $definition -ApiVersion '2025-03-01' } |
                Should -Throw "*Policy definition name 'policy#name'*"

            Should -Invoke Invoke-AzRestMethod -Times 0
        }

        It 'rejects an invalid policy set definition name before the REST call' {
            $definition = [pscustomobject]@{ name = 'policySet#name' }

            { Set-AzPolicySetDefinitionRestMethod -DefinitionObj $definition -ApiVersion '2025-03-01' } |
                Should -Throw "*Policy set definition name 'policySet#name'*"

            Should -Invoke Invoke-AzRestMethod -Times 0
        }

        It 'rejects an invalid policy assignment name before the REST call' {
            $assignment = [pscustomobject]@{ name = 'assignment#name' }

            { Set-AzPolicyAssignmentRestMethod -AssignmentObj $assignment -ApiVersion '2025-03-01' } |
                Should -Throw "*Policy assignment name 'assignment#name'*"

            Should -Invoke Invoke-AzRestMethod -Times 0
        }

        It 'rejects an invalid policy exemption name before the REST call' {
            $exemption = [pscustomobject]@{ name = 'exemption#name' }

            { Set-AzPolicyExemptionRestMethod -ExemptionObj $exemption -ApiVersion '2022-07-01-preview' } |
                Should -Throw "*Policy exemption name 'exemption#name'*"

            Should -Invoke Invoke-AzRestMethod -Times 0
        }
    }

    It 'encodes policy exemption names' {
        $id = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyExemptions/exemption-#1'

        Remove-AzResourceByIdRestMethod -Id $id -ApiVersion '2022-07-01-preview'

        Should -Invoke Invoke-AzRestMethod -ParameterFilter {
            $Path -eq "$($id.Replace('#', '%23'))?api-version=2022-07-01-preview" -and $Method -eq 'DELETE'
        }
    }
}
