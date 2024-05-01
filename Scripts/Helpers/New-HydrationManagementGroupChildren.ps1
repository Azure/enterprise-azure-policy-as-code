
<#
.SYNOPSIS
    This is a function that will not be published in the final version of this module, and should not be used as a standalone unless you are developing new code using this function.
    This function creates new children for a management group, duplicating a hierarchy from a source management group. It uses a prefix to update the names to manage uniqueness requirements.
.DESCRIPTION
    The New-HydrationManagementGroupChildren function takes a parent group name and a list of child names. 
    It then creates new child groups under the specified parent group.
.PARAMETER Hierarchy
    An output from get-azmanagementgroup -GroupName $ManagementGroup -expand -Recurse, this will be used as the source for the management group copy job.
.PARAMETER Suffix
    The prefix to be used for naming in the destination of the management group copy job.
.PARAMETER Prefix
    The suffix to be used for naming in the destination of the management group copy job.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function New-HydrationManagementGroupChildren {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Hierarchy,
        [Parameter(Mandatory = $false)]
        [string]
        $Prefix,
        [Parameter(Mandatory = $false)]
        [string]
        $Suffix
    )
    if (!($Suffix)) {
        $Suffix = ""
    }
    if (!($Prefix)) {
        $Prefix = ""
    }
    Write-Debug "Suffix: $Suffix"
    Write-Debug "Prefix: $Prefix"
    foreach ($child in $Hierarchy.Children) {
        $destParentGroupId = $( -join ("/providers/Microsoft.Management/managementGroups/", $Prefix, $Hierarchy.Name, $Suffix))
        if ($child.Type -eq "Microsoft.Management/managementGroups") {
            $newMGName = $( -join ($Prefix, $child.Name, $Suffix))
            Write-Information "    Creating $newMGName in $destParentGroupId..."
            $i = 0
            do {
                $i++
                if ($i -gt 1) {
                    Write-Warning "    Last attempt failed, this is attempt number $i..."
                }
                # Error action included because timeouts happen frequently, but mean nothing. Rather than have responses cause concern, we simply suppress the error and test. It takes longer, but this should be a task that is run very infrequently outside of a lab environment.
                $newMg = New-AzManagementGroup -GroupName $newMGName -DisplayName $( -join ($Prefix, $child.DisplayName, $Suffix)) -ParentId $destParentGroupId -ErrorAction SilentlyContinue
            }until($(Get-AzManagementGroup -GroupName $newMGName) -or $i -eq 10)
            $mgChildren = $child.Children | Where-Object { $_.Type -eq "Microsoft.Management/managementGroups" }
            if ($mgChildren.count -gt 0) {
                Write-Information "    Creating child Management Groups of $(-join($Prefix,$child.Name,$Suffix)) from $($mgChildren.Name -join ", ")..."
                New-HydrationManagementGroupChildren -Hierarchy $child -Prefix $Prefix -Suffix $Suffix
            }
        }
    }
}