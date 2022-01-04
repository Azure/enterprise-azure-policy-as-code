param(
    $Path
)

$subs = Get-AzSubscription -TenantId "e898ff4a-4b69-45ee-a3ae-1cd6f239feb2" | ? {$_.state -EQ "Enabled"}

$assignments = @()

foreach ($sub in $subs)
{

    Set-AzContext -Subscription $sub.name

    Write-Output $sub.Name

    $assignments += Get-AzRoleAssignment | ? {$_.ObjectType -eq "User" -and $_.Scope -notlike "*managementGroups*"} | select displayname, signinname, RoleDefinitionName, scope, @{
                Name       = 'Subscription'
                Expression = { $sub.Name }
            }

}

$assignments

if ($path)
{
    Export-Csv -Path $path -NoTypeInformation
}