function Get-HydrationChildManagementGroupNameList {
    <#
    .SYNOPSIS
        This function retrieves a list of all child management groups of a given management group.
    
    .DESCRIPTION
        The Get-HydrationChildManagementGroupNameList function retrieves a list of all child management groups of a given management group. It takes one parameter: ManagementGroupName.
    
    .PARAMETER ManagementGroupName
        The name of the management group for which to retrieve child management groups.
    
    .EXAMPLE
        Get-HydrationChildManagementGroupNameList -ManagementGroupName "MyManagementGroup"
    
        This example retrieves a list of all child management groups of the management group "MyManagementGroup".
    
    .NOTES
        The function retrieves all child management groups of the given management group by recursively iterating over the management groups and their children.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ManagementGroupName
    )
    $childMgsList = @()
    $mgs = Get-AzManagementGroupRestMethod -GroupId $ManagementGroupName -Expand  -Recurse 
    do {
        $childMgs = @()
        foreach ($mg in $mgs) {
            $childMgsList += $mg
            foreach ($cMg in $mg.properties.children) {
                $childMgs += $cMg.properties.children | Where-Object { $_.Type -eq "Microsoft.Management/managementGroups" }
            } 
        }
        Clear-Variable mgs
        $mgs = $childMgs
    } until ($childMgs.count -eq 0)
    return $childMgsList
}