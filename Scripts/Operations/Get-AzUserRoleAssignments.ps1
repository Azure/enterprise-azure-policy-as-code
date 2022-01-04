param(
    $Path
)

$subs = Get-AzSubscription -TenantId "tenant-id-guid" | ? { $_.state -EQ "Enabled" }

$assignments = @()

foreach ($sub in $subs) {

    Set-AzContext -Subscription $sub.name

    Write-Output $sub.Name

    $assignments += Get-AzRoleAssignment | ? { $_.ObjectType -eq "User" -and $_.Scope -notlike "*managementGroups*" } | select displayname, signinname, RoleDefinitionName, scope, @{
        Name       = 'Subscription'
        Expression = { $sub.Name }
    }

}

$assignments

if ($path) {
    Export-Csv -Path $path -NoTypeInformation
}