function Confirm-PolicyResourceExclusions {
    [CmdletBinding()]
    param (
        $TestId,
        $ResourceId,
        $ScopeTable,
        $IncludeResourceGroups,
        $ExcludedScopes,
        $ExcludedIds,
        $PolicyResourceTable
    )

    $testResourceIdParts = Split-AzPolicyResourceId -Id $TestId
    $scope = $testResourceIdParts.scope
    $scopeType = $testResourceIdParts.scopeType

    $resourceIdParts = $testResourceIdParts
    if ($TestId -ne $ResourceId) {
        $resourceIdParts = Split-AzPolicyResourceId -Id $ResourceId
    }

    if ($scopeType -eq "builtin") {
        return $true, $resourceIdParts
    }
    if (!$ScopeTable.ContainsKey($scope)) {
        $PolicyResourceTable.counters.unmanagedScopes += 1
        return $false, $resourceIdParts
    }
    $scopeEntry = $ScopeTable.$scope
    $parentList = $scopeEntry.parentList
    if ($null -eq $parentList) {
        Write-Error "Code bug parentList is $null $($scopeEntry | ConvertTo-Json -Depth 100 -Compress)" -ErrorAction Stop
    }
    if (!$IncludeResourceGroups -and $scopeType -eq "resourceGroups") {
        Write-Verbose "Exclude(resourceGroup) $($ResourceId)"
        $PolicyResourceTable.counters.excluded += 1
        return $false, $resourceIdParts
    }
    foreach ($testScope in $ExcludedScopes) {
        if ($scope -like $testScope -or $parentList.ContainsKey($testScope)) {
            Write-Verbose "Exclude(scope,$testScope) $($ResourceId)"
            $PolicyResourceTable.counters.excluded += 1
            return $false, $resourceIdParts
        }
        elseif ($testScope -contains "*") {
            foreach ($parentScope in $parentList.Keys) {
                if ($parentScope -like $testScope) {
                    Write-Verbose "Exclude(scope,$testScope) $($ResourceId)"
                    $PolicyResourceTable.counters.excluded += 1
                    return $false, $resourceIdParts
                }
            }
        }
    }
    foreach ($testExcludedId in $ExcludedIds) {
        if ($TestId -like $testExcludedId) {
            Write-Verbose "Exclude(id,$testExcludedId) $($ResourceId)"
            $PolicyResourceTable.counters.excluded += 1
            return $false, $resourceIdParts
        }
    }
    return $true, $resourceIdParts
}
