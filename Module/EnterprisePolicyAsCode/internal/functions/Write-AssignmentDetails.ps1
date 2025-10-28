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
        Write-Information "$($Prefix) '$($DisplayName)' at $($shortScope)"
    }
    else {
        Write-Information "'$($DisplayName)' at $($shortScope)"
    }
    if ($IdentityStatus.requiresRoleChanges) {
        foreach ($role in $IdentityStatus.updated) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            if (!$role.properties.crossTenant) {
                Write-Information "    update role assignment description $($role.roleDisplayName) at $($roleShortScope)"
            }
            else {
                Write-Information "    update role assignment description $($role.roleDisplayName) at $($roleShortScope) (remote)"
            }
        }
        foreach ($role in $IdentityStatus.added) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            if (!$role.properties.crossTenant) {
                Write-Information "    add role $($role.roleDisplayName) at $($roleShortScope)"
            }
            else {
                Write-Information "    add role $($role.roleDisplayName) at $($roleShortScope) (remote)"
            }
        }
        foreach ($role in $IdentityStatus.removed) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            if (!$role.crossTenant) {
                Write-Information "    remove role $($role.roleDisplayName) at $($roleShortScope)"
            }
            else {
                Write-Information "    remove role $($role.roleDisplayName) at $($roleShortScope) (remote)"
            }
        }
    }
}
