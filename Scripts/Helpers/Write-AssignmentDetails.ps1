function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $DisplayName,
        $Scope,
        $Prefix,
        $IdentityStatus
    )

    $shortScope = $Scope -replace "/providers/Microsoft.Management", ""
    if ($Prefix -ne "") {
        Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "info" -Indent 4
    }
    else {
        Write-ModernStatus -Message "$($DisplayName) at $($shortScope)" -Status "info" -Indent 4
    }
    if ($IdentityStatus.requiresRoleChanges) {
        foreach ($role in $IdentityStatus.updated) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            if (!$role.properties.crossTenant) {
                Write-ModernStatus -Message "Update role assignment description: $($role.roleDisplayName) at $($roleShortScope)" -Status "warning" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Update role assignment description: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "warning" -Indent 6
            }
        }
        foreach ($role in $IdentityStatus.added) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            if (!$role.properties.crossTenant) {
                Write-ModernStatus -Message "Add role: $($role.roleDisplayName) at $($roleShortScope)" -Status "success" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Add role: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "success" -Indent 6
            }
        }
        foreach ($role in $IdentityStatus.removed) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            if (!$role.crossTenant) {
                Write-ModernStatus -Message "Remove role: $($role.roleDisplayName) at $($roleShortScope)" -Status "error" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Remove role: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "error" -Indent 6
            }
        }
    }
}
