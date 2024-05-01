<#
.SYNOPSIS
    Removes a Management Group and all of its children recursively.

.DESCRIPTION
    The Remove-HydrationManagementGroupRecursively cmdlet removes a Management Group and all of its children recursively. This is useful for cleaning up Management Groups that were created as part of a test or demonstration.
    
.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    $Hierarchy
)
$InformationPreference = "Continue"
# $hierarchy = Get-AzManagementGroup -GroupName $Hierarchy -Expand -Recurse
foreach ($child in $Hierarchy.Children) {
    if ($child.Type -eq "Microsoft.Management/managementGroups") {
        # Error action included because timeouts happen frequently, but mean nothing. Rather than have responses cause concern, we simply suppress the error.
        if ($child.Children) {
            Write-Information "    Removing child objects of $($child.Name) -- $($child.Children.Name -join ", ")..."
            Remove-HydrationManagementGroupRecursively $child
        }
        if ($(Get-AzManagementGroup -GroupName $($child.Name) -ErrorAction SilentlyContinue)) {
            Write-Information "    Removing $($child.Name)..."
            $remMg = Remove-AzManagementGroup -GroupName $($child.Name)
        }
        else {
            Write-Information "    $($child.Name) has already been removed..."
        }
    }
}
if ($(Get-AzManagementGroup -GroupName $Hierarchy.Name -ErrorAction SilentlyContinue)) {
    Write-Information "    Removing $($Hierarchy.Name)..."
    $remMg = Remove-AzManagementGroup -GroupName $($Hierarchy.Name)
}
else {
    Write-Information "    $($Hierarchy.Name) has already been removed..."
}
