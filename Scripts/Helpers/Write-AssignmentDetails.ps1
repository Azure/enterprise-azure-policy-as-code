function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $DisplayName,
        $Scope,
        $Prefix,
        $IdentityStatus,
        $ScopeTable
    )

    $tenantScopes = $ScopeTable.keys
    $shortScope = $Scope -replace "/providers/Microsoft.Management", ""
    if ($Prefix -ne "") {
        if ($Prefix -like "*update*") {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "update" -Indent 4
        }
        elseif ($Prefix -like "*new*") {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "success" -Indent 4
        }
        elseif ($Prefix -like "*delete*") {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "error" -Indent 4
        }
        else {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "error" -Indent 4
        }
    }
    else {
        Write-ModernStatus -Message "$($DisplayName) at $($shortScope)" -Status "info" -Indent 4
    }
    if ($IdentityStatus.requiresRoleChanges) {
        foreach ($role in $IdentityStatus.updated) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            $roleShortScopeSub = ($roleScope -split '/')[0..2] -join '/'
            if (!$role.properties.crossTenant) {
                Write-ModernStatus -Message "Update role assignment description: $($role.roleDisplayName) at $($roleShortScope)" -Status "update" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Update role assignment description: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "update" -Indent 6
            }
            if (($tenantScopes -notcontains $roleScope) -and ($tenantScopes -notcontains $roleShortScopeSub)) {
                Write-ModernStatus -Message "Role assignments to external scopes may cause false positives!" -Status "warning" -Indent 8
            }
        }
        foreach ($role in $IdentityStatus.added) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            $roleShortScopeSub = ($roleScope -split '/')[0..2] -join '/'
            if (!$role.properties.crossTenant) {
                Write-ModernStatus -Message "Add role: $($role.roleDisplayName) at $($roleShortScope)" -Status "success" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Add role: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "success" -Indent 6
            }
            if (($tenantScopes -notcontains $roleScope) -and ($tenantScopes -notcontains $roleShortScopeSub)) {
                Write-ModernStatus -Message "Role assignments to external scopes may cause false positives!" -Status "warning" -Indent 8
            }
        }
        foreach ($role in $IdentityStatus.removed) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            $roleShortScopeSub = ($roleScope -split '/')[0..2] -join '/'
            if (!$role.crossTenant) {
                Write-ModernStatus -Message "Remove role: $($role.roleDisplayName) at $($roleShortScope)" -Status "error" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Remove role: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "error" -Indent 6
            }
            if (($tenantScopes -notcontains $roleScope) -and ($tenantScopes -notcontains $roleShortScopeSub)) {
                Write-ModernStatus -Message "Role assignments to external scopes may cause false positives!" -Status "warning" -Indent 8
            }
        }
    }
}
