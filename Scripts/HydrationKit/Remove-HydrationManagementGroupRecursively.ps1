
<#
.SYNOPSIS
    Removes a Management Group and all of its children recursively.

.DESCRIPTION
    The Remove-HydrationManagementGroupRecursively cmdlet removes a Management Group and all of its children recursively. This is useful for cleaning up Management Groups that were created as part of a test or demonstration.
    
.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>

function Remove-HydrationManagementGroupRecursively {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The root of the Management Group structure that will be deleted.")]
        $HierarchyRootGroupName       
    ) 

    $InformationPreference = "Continue"
    $fullHierarchy = Get-AzManagementGroupRestMethod -GroupId $HierarchyRootGroupName -Expand  -Recurse 
    Write-Debug "Starting Outer Loop"
    Remove-HydrationChildHierarchy -ChildHierarchy $fullHierarchy.properties.children
    Write-Debug "Leaving Outer Loop"
    # Test to ensure deletes were completed
    if ($(Get-AzManagementGroupRestMethod -GroupId $HierarchyRootGroupName -Expand  -Recurse).properties.children.count -gt 0) {
        Write-Error "Child Deletions Failed, rerun script."
    }
    # Delete the root group
    do {
        try {
            $null = Get-AzManagementGroupRestMethod -GroupId $HierarchyRootGroupName -ErrorAction SilentlyContinue
        }
        catch {
            if ($_.Exception.Message -match "NotFound") {
                Write-Information "    $HierarchyRootGroupName confirmed to be removed..."
                $complete = $true
            }
        }
        if (!($true -eq $complete)) {
            Write-Information "    Removing $HierarchyRootGroupName..."
            $null = Remove-AzManagementGroup -GroupName $HierarchyRootGroupName
            try {
                $null = Get-AzManagementGroupRestMethod -GroupId $HierarchyRootGroupName -ErrorAction SilentlyContinue
            }
            catch {
                if ($_.Exception.Message -match "NotFound") {
                    Write-Information "    $HierarchyRootGroupName confirmed to be removed..."
                    $complete = $true
                }
            }
            if (!($complete -eq $true)) {
                Write-Information "    $HierarchyRootGroupName generated an error during deletion, retrying $(6-$i) more times..."
                $complete = $false
                $i++
            }
        }
    }until($true -eq $complete -or $i -eq 6)
}