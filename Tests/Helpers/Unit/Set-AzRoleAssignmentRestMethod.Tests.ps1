BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\..\Scripts\Helpers\RestMethods\Set-AzRoleAssignmentRestMethod.ps1')

    function Invoke-AzRestMethod { param($Path, $Method, $Payload) }
    function Write-ModernStatus { param($Message, $Status, $Indent) }
}

Describe 'Set-AzRoleAssignmentRestMethod retries' {
    BeforeEach {
        $pacEnvironment = @{
            apiVersions = @{ roleAssignments = '2022-04-01' }
        }
        $roleAssignment = @{
            scope = '/subscriptions/test'
            assignmentId = '/subscriptions/test/providers/Microsoft.Authorization/policyAssignments/test'
            properties = @{
                principalId = 'principal'
                roleDefinitionId = '/providers/Microsoft.Authorization/roleDefinitions/test'
                principalType = 'ServicePrincipal'
            }
        }
        $script:abacError = 'has an authorization with ABAC condition that is not fulfilled to perform action'
        $script:delegatedError = 'delegatedManagedIdentityResourceId in the request is set to an invalid value'
        $script:responses = [System.Collections.Generic.Queue[object]]::new()
        $script:requests = [System.Collections.Generic.List[object]]::new()
        Mock Write-ModernStatus
        Mock Invoke-AzRestMethod {
            $script:requests.Add(@{
                Path = $Path
                Method = $Method
                Body = ConvertFrom-Json -InputObject $Payload -AsHashtable
            })
            if ($script:requests.Count -gt 2) {
                throw 'Unexpected third request'
            }
            if ($script:responses.Count -eq 0) {
                throw 'Unexpected request'
            }
            $script:responses.Dequeue()
        }
    }

    It 'preserves successful request behavior with tenant <Tenant> and skipDelegated <Skip>' -ForEach @(
        @{ Tenant = $null; Skip = $false; Delegated = $false }
        @{ Tenant = 'managed-tenant'; Skip = $false; Delegated = $true }
        @{ Tenant = 'managed-tenant'; Skip = $true; Delegated = $false }
    ) {
        if ($Tenant) {
            $pacEnvironment.managedTenantId = $Tenant
        }
        $script:responses.Enqueue(@{ StatusCode = 201; Content = '{}' })

        Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -PacEnvironment $pacEnvironment -skipDelegated $Skip

        $script:requests.Count | Should -Be 1
        $script:requests[0].Method | Should -Be 'PUT'
        $script:requests[0].Body.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -Be $Delegated
        $roleAssignment.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -BeFalse
        Should -Invoke Write-ModernStatus -Times 1 -Exactly -ParameterFilter { $Status -eq 'success' }
    }

    It 'retries an ABAC failure once with delegation and the same resource path' {
        $script:responses.Enqueue(@{ StatusCode = 403; Content = $script:abacError })
        $script:responses.Enqueue(@{ StatusCode = 201; Content = '{}' })

        Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -PacEnvironment $pacEnvironment

        $script:requests.Count | Should -Be 2
        $script:requests[0].Body.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -BeFalse
        $script:requests[1].Body.properties.delegatedManagedIdentityResourceId | Should -Be $roleAssignment.assignmentId
        $script:requests[1].Path | Should -Be $script:requests[0].Path
        $pacEnvironment.ContainsKey('managedTenantId') | Should -BeFalse
        $roleAssignment.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -BeFalse
        Should -Invoke Write-ModernStatus -Times 1 -Exactly -ParameterFilter { $Status -eq 'success' }
    }

    It 'reports persistent ABAC errors and leaves subsequent assignments unchanged' {
        $script:responses.Enqueue(@{ StatusCode = 403; Content = $script:abacError })
        $script:responses.Enqueue(@{ StatusCode = 403; Content = "$script:abacError (retry)" })

        Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -PacEnvironment $pacEnvironment

        $script:requests.Count | Should -Be 2
        Should -Invoke Write-ModernStatus -Times 1 -Exactly -ParameterFilter {
            $Status -eq 'error' -and $Message -like '*ABAC Permissions Issue*' -and
            $Message.Contains("$script:abacError (retry)") -and $Message.Contains('/subscriptions/test')
        }
        $script:requests.Clear()
        $script:responses.Enqueue(@{ StatusCode = 201; Content = '{}' })

        Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -PacEnvironment $pacEnvironment

        $script:requests.Count | Should -Be 1
        $script:requests[0].Body.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -BeFalse
        $pacEnvironment.ContainsKey('managedTenantId') | Should -BeFalse
        $roleAssignment.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -BeFalse
    }

    It 'bounds the Lighthouse fallback when the second response is <SecondStatus>' -ForEach @(
        @{ SecondStatus = 201; SecondContent = '{}'; ExpectedStatus = 'success' }
        @{ SecondStatus = 400; SecondContent = 'delegatedManagedIdentityResourceId in the request is set to an invalid value'; ExpectedStatus = 'error' }
        @{ SecondStatus = 403; SecondContent = 'has an authorization with ABAC condition that is not fulfilled to perform action'; ExpectedStatus = 'error' }
    ) {
        $pacEnvironment.managedTenantId = 'managed-tenant'
        $script:responses.Enqueue(@{ StatusCode = 400; Content = $script:delegatedError })
        $script:responses.Enqueue(@{ StatusCode = $SecondStatus; Content = $SecondContent })

        Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -PacEnvironment $pacEnvironment

        $script:requests.Count | Should -Be 2
        $script:requests[0].Body.properties.delegatedManagedIdentityResourceId | Should -Be $roleAssignment.assignmentId
        $script:requests[1].Body.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -BeFalse
        $script:requests[1].Path | Should -Be $script:requests[0].Path
        $pacEnvironment.managedTenantId | Should -Be 'managed-tenant'
        $roleAssignment.properties.ContainsKey('delegatedManagedIdentityResourceId') | Should -BeFalse
        Should -Invoke Write-ModernStatus -Times 1 -Exactly -ParameterFilter { $Status -eq $ExpectedStatus }
    }

    It 'does not retry ABAC failures when delegation is already enabled or explicitly skipped' -ForEach @(
        @{ Skip = $false }
        @{ Skip = $true }
    ) {
        $pacEnvironment.managedTenantId = 'managed-tenant'
        $script:responses.Enqueue(@{ StatusCode = 403; Content = $script:abacError })

        Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -PacEnvironment $pacEnvironment -skipDelegated $Skip

        $script:requests.Count | Should -Be 1
        $pacEnvironment.managedTenantId | Should -Be 'managed-tenant'
        Should -Invoke Write-ModernStatus -Times 1 -Exactly -ParameterFilter {
            $Status -eq 'error' -and $Message.Contains($script:abacError)
        }
    }

    It 'does not alternate between ABAC and delegated identity retries' {
        $script:responses.Enqueue(@{ StatusCode = 403; Content = $script:abacError })
        $script:responses.Enqueue(@{ StatusCode = 400; Content = $script:delegatedError })

        Set-AzRoleAssignmentRestMethod -RoleAssignment $roleAssignment -PacEnvironment $pacEnvironment

        $script:requests.Count | Should -Be 2
        Should -Invoke Write-ModernStatus -Times 1 -Exactly -ParameterFilter {
            $Status -eq 'error' -and $Message.Contains($script:delegatedError)
        }
    }
}
