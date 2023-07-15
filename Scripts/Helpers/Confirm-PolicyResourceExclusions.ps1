function Confirm-PolicyResourceExclusions {
    [CmdletBinding()]
    param (
        $TestId,
        $ResourceId,
        $PolicyResource,
        $ScopeTable,
        $IncludeResourceGroups,
        $ExcludedScopes,
        $ExcludedIds,
        $PolicyResourceTable
    )

    $resourceIdParts = Split-AzPolicyResourceId -Id $TestId
    $scope = $resourceIdParts.scope
    $scopeType = $resourceIdParts.scopeType

    if ($scopeType -eq "builtin") {
        return $true, $resourceIdParts
    }
    if (!$ScopeTable.ContainsKey($scope)) {
        $PolicyResourceTable.counters.unMangedScope += 1
        $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
        return $false, $resourceIdParts
    }
    $scopeEntry = $ScopeTable.$scope
    $parentList = $scopeEntry.parentList
    if ($null -eq $parentList) {
        Write-Error "Code bug parentList is $null $($scopeEntry | ConvertTo-Json -Depth 100 -Compress)"
    }
    if (!$IncludeResourceGroups -and $scopeType -eq "resourceGroups") {
        # Write-Information "    Exclude(resourceGroup) $($ResourceId)"
        $PolicyResourceTable.counters.excludedScopes += 1
        $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
        return $false, $resourceIdParts
    }
    foreach ($testScope in $ExcludedScopes) {
        if ($scope -eq $testScope -or $parentList.ContainsKey($testScope)) {
            # Write-Information "Exclude(scope,$testScope) $($ResourceId)"
            $PolicyResourceTable.counters.excludedScopes += 1
            $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
            return $false, $resourceIdParts
        }
    }
    foreach ($testExcludedId in $ExcludedIds) {
        if ($TestId -like $testExcludedId) {
            # Write-Information "Exclude(id,$testExcludedId) $($ResourceId)"
            $PolicyResourceTable.counters.excluded += 1
            $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
            return $false, $resourceIdParts
        }
    }
    return $true, $resourceIdParts
}
