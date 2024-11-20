function Remove-HydrationChildHierarchy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ChildHierarchy 
    )
    foreach ($child in $ChildHierarchy) {
        if ($child.Type -eq "Microsoft.Management/managementGroups") {
            # Error action included because timeouts happen frequently, but mean nothing. Rather than have responses cause concern, we simply suppress the error.
            if ($child.children) {
                Write-Information "    Removing child objects of $($child.Name) -- $($child.children.Name -join ", ")..."
                # try {
                Write-Debug "Starting Inner Loop"
                $null = Remove-HydrationChildHierarchy -ChildHierarchy $child.children -ErrorAction SilentlyContinue # Error was meaningless
                Write-Debug "Leaving Inner Loop"
                # }
                # catch {
                #     write-error $_
                # }
            }
            do {
                Write-Information "    Removing $($child.Name)..."
                $null = Remove-AzManagementGroup -GroupName $($child.Name)
                try {
                    $null = Get-AzManagementGroupRestMethod -GroupId $($child.Name) -ErrorAction SilentlyContinue
                }
                catch {
                    if ($_.Exception.Message -match "NotFound") {
                        Write-Information "    $($child.Name) confirmed to be removed..."
                        $complete = $true
                    }
                    else {
                        Write-Information "    $($child.Name) generated an error during deletion, retrying $(6-$i) more times..."
                        $complete = $false
                        $i++
                    }
                }
                # }
            }until($true -eq $complete -or $i -eq 6)
        }
    }
}