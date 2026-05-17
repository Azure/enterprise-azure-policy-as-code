function Confirm-PolicyResourceExclusions {
    [CmdletBinding()]
    param (
        $TestId,
        $ResourceId,
        $ScopeTable,
        $ExcludedScopesTable,
        $ExcludedIds = @(),
        $PolicyResourceTable = $null
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
    if (-not $ScopeTable.ContainsKey($scope)) {
        Write-Verbose "Unmanaged scope '$scope', resource '$($ResourceId)'"
        if ($null -ne $PolicyResourceTable) {
            $PolicyResourceTable.counters.unmanagedScopes += 1
        }
        return $false, $resourceIdParts
    }
    if ($null -ne $ExcludedScopesTable) {
        if ($ExcludedScopesTable.ContainsKey($scope)) {
            Write-Verbose "Excluded scope '$scope', resource '$($ResourceId)'"
            if ($null -ne $PolicyResourceTable) {
                $PolicyResourceTable.counters.excluded += 1
            }
            # if ($resourceIdParts.kind -eq "policyAssignments") {
            #     $excludedScope = $ExcludedScopesTable.$scope
            #     $null = $null
            # }
            return $false, $resourceIdParts
        }
    }
    if ($null -ne $ExcludedIds) {
        foreach ($testExcludedId in $ExcludedIds) {
            if ($TestId -like $testExcludedId) {
                Write-Verbose "Excluded id '$($ResourceId)'"
                if ($null -ne $PolicyResourceTable) {
                    $PolicyResourceTable.counters.excluded += 1
                }
                return $false, $resourceIdParts
            }
        }
    }
    return $true, $resourceIdParts
}
