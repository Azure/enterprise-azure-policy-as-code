function Set-UniqueRoleAssignmentScopes {
    [CmdletBinding()]
    param (
        [string] $ScopeId,
        [hashtable] $UniqueRoleAssignmentScopes
    )

    $splits = $ScopeId -split "/"
    $segments = $splits.Length

    $scopeType = switch ($segments) {
        3 {
            "subscriptions"
            break
        }
        5 {
            $splits[3]
            break
        }
        { $_ -gt 5 } {
            "resources"
            break
        }
        Default {
            "unknown"
        }
    }
    $table = $UniqueRoleAssignmentScopes.$scopeType
    $table[$ScopeId] = $scopeType
}
