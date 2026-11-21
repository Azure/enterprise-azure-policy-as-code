BeforeAll {
    $helpersPath = Join-Path $PSScriptRoot '..\..\..\Scripts\Helpers'
    foreach ($helper in @(
        'Get-GlobalSettings'
        'Get-PacFolders'
        'New-ErrorInfo'
        'Add-ErrorMessage'
        'Write-ErrorsFromErrorInfo'
        'Build-ScopeTableForDeploymentRootScope'
        'Build-ScopeTableForSubscription'
        'Confirm-PolicyResourceExclusions'
        'Split-AzPolicyResourceId'
    )) {
        . (Join-Path $helpersPath "$helper.ps1")
    }

    function Write-ModernSection {}
    function Write-ModernStatus {}
    function Search-AzGraphAllItems {}
    function Get-AzSubscription {
        [CmdletBinding()]
        param($SubscriptionId, $TenantId)
    }
}

Describe 'Build-ScopeTableForDeploymentRootScope resource-group exclusions' {
    BeforeEach {
        $script:subscriptionId = '11111111-1111-1111-1111-111111111111'
        $script:subscriptionScope = "/subscriptions/$script:subscriptionId"
        $script:resourceGroupId = "$script:subscriptionScope/resourceGroups/excluded-rg"
        $script:otherResourceGroupId = "$script:subscriptionScope/resourceGroups/managed-rg"
        $script:settings = @{
            pacOwnerId = '22222222-2222-2222-2222-222222222222'
            pacEnvironments = @(
                @{
                    pacSelector = 'test'
                    cloud = 'AzureCloud'
                    tenantId = '33333333-3333-3333-3333-333333333333'
                    deploymentRootScope = $script:subscriptionScope
                    managedIdentityLocation = 'australiaeast'
                    globalNotScopes = @()
                    desiredState = @{
                        strategy = 'full'
                        keepDfcSecurityAssignments = $true
                        excludedScopes = @()
                    }
                }
            )
        }

        Mock Get-AzSubscription {
            @{ Id = $script:subscriptionId; Name = 'Test subscription' }
        }
        Mock Search-AzGraphAllItems {
            foreach ($name in @('excluded-rg', 'managed-rg')) {
                @{
                    id = "$script:subscriptionScope/resourceGroups/$name"
                    subscriptionId = $script:subscriptionId
                    name = $name
                    type = 'microsoft.resources/subscriptions/resourcegroups'
                    properties = @{ provisioningState = 'Succeeded' }
                }
            }
        }
    }

    It 'applies <Scenario> from parsed settings to scopes and policy inventory filtering' -ForEach @(
        @{ Scenario = 'all resource groups'; Pattern = '/subscriptions/*/resourceGroups/*'; Excluded = $true; OtherExcluded = $true }
        @{ Scenario = 'a resource-group name wildcard'; Pattern = '/subscriptions/*/resourceGroups/excluded-*'; Excluded = $true; OtherExcluded = $false }
        @{ Scenario = 'an exact resource-group ID'; Pattern = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/excluded-rg'; Excluded = $true; OtherExcluded = $false }
        @{ Scenario = 'a nonmatching resource group'; Pattern = '/subscriptions/*/resourceGroups/unrelated-*'; Excluded = $false; OtherExcluded = $false }
        @{ Scenario = 'no exclusions'; Pattern = $null; Excluded = $false; OtherExcluded = $false }
    ) {
        if ($null -ne $Pattern) {
            $script:settings.pacEnvironments[0].desiredState.excludedScopes = @($Pattern)
        }
        $script:settings | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath (Join-Path $TestDrive 'global-settings.jsonc')
        $globalSettings = Get-GlobalSettings -DefinitionsRootFolder $TestDrive
        $pacEnvironment = $globalSettings.pacEnvironments.test

        $scopeTable = Build-ScopeTableForDeploymentRootScope -PacEnvironment $pacEnvironment

        $scopeTable[$script:resourceGroupId].isExcluded | Should -Be $Excluded
        $scopeTable[$script:otherResourceGroupId].isExcluded | Should -Be $OtherExcluded
        $scopeTable.root.isExcluded | Should -BeFalse
        $scopeTable.root.excludedScopesTable.ContainsKey($script:resourceGroupId) | Should -Be $Excluded
        $scopeTable.root.excludedScopesTable.ContainsKey($script:otherResourceGroupId) | Should -Be $OtherExcluded
        $scopeTable[$script:resourceGroupId].isInGlobalNotScope | Should -BeFalse
        $scopeTable.root.notScopesList.Count | Should -Be 0

        foreach ($scope in @($script:resourceGroupId, $script:otherResourceGroupId)) {
            $assignmentId = "$scope/providers/Microsoft.Authorization/policyAssignments/test-assignment"
            $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                -TestId $assignmentId `
                -ResourceId $assignmentId `
                -ScopeTable $scopeTable `
                -ExcludedScopesTable $scopeTable.root.excludedScopesTable

            $expectedExcluded = if ($scope -eq $script:resourceGroupId) { $Excluded } else { $OtherExcluded }
            $included | Should -Be (-not $expectedExcluded)
            $resourceIdParts.scope | Should -Be $scope
        }
    }
}
