<#
.SYNOPSIS
    Updates the assignment destination in the given assignment file.

.DESCRIPTION
    This function updates the assignment destination in the specified assignment file. It allows you to provide a new management group name, prefix, or suffix to update the name of the management group destination.
    New Management Group assignments are generally used when items are moving within the hierarchy, such as when replacing a current hierarchy with a CAF3 hierarchy that utilizes the standard naming convention.
    The suffix and prefix are generally used in conjunction with similar name modification options used when cloning a hierarchy.

.PARAMETER PacSelectorName
    The name of the PAC selector to update.

.PARAMETER AssignmentFile
    The path to the assignment file to update.

.PARAMETER NewManagementGroupName
    The new name for the management group destination.

.PARAMETER NewManagementGroupPrefix
    The new prefix for the management group destination.

.PARAMETER NewManagementGroupSuffix
    The new suffix for the management group destination.

.PARAMETER SuppressReturn
    Suppresses the return of the updated assignment data.

.PARAMETER Output
    The path to the output directory where the updated assignment file will be saved. Default is "./Output".

.PARAMETER SuppressFileOutput
    Suppresses the output of the updated assignment file.

.EXAMPLE
    Update-HydrationAssignmentDestination -PacSelectorName "MyPacSelector" -AssignmentFile "C:\path\to\assignment.json" -NewManagementGroupName "NewMGName"

    This example updates the assignment destination in the "assignment.json" file by replacing the management group name with "NewMGName".

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
        
#>

# TODO: To process release flows, we'll need to be able to add multiple destinations.
[CmdletBinding(DefaultParameterSetName = 'Static')]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $PacSelectorName,
    [Parameter(Mandatory = $true)]
    $AssignmentFile,
    [Parameter(Mandatory = $true)]
    [string]
    $OldManagementGroupName,
    [Parameter(Mandatory = $true, ParameterSetName = 'Static')]
    [string]
    $NewManagementGroupName,
    [Parameter(Mandatory = $false, ParameterSetName = 'Dynamic')]
    [string]
    $NewManagementGroupPrefix,
    [Parameter(Mandatory = $false, ParameterSetName = 'Dynamic')]
    [string]
    $NewManagementGroupSuffix,
    [switch]
    $SuppressReturn,
    [Parameter(Mandatory = $false)]
    [string]
    $Output = "./Output",
    [switch]
    $SuppressFileOutput
)
        
if (!($NewManagementGroupSuffix -or $NewManagementGroupName -or $NewManagementGroupPrefix)) {
    Write-Error "You must provide a NewManagementGroupSuffix, NewManagementGroupName, or NewManagementGroupPrefix for this function to be able to update the name of the management group destination."
    return
}
if (Test-Path $AssignmentFile) {
    $assignmentData = Get-Content $AssignmentFile | ConvertFrom-Json -Depth 10
}
else {
    Write-Error "The assignment file does not exist at the specified path."
    return
}
if (!($NewManagementGroupName)) {
    $NewManagementGroupName = -join ($NewManagementGroupPrefix, $OldManagementGroupName, $NewManagementGroupSuffix)
}
$oldManagementGroupProvider = "/providers/Microsoft.Management/managementGroups/" + $OldManagementGroupName
if ($assignmentData.Children.Count -gt 0) {   
    $ci = 0     
    foreach ($c in $assignmentData.Children) {
        if ($c.scope.($PacSelectorName)) {
            foreach ($a in $c.scope.($PacSelectorName)) {
                # Write-Host "Wait here"
                if ($a -eq $oldManagementGroupProvider) {
                    $a = "/providers/Microsoft.Management/managementGroups/" + $NewManagementGroupName
                    Write-Information "    Updated Child $($c.nodeName)..."
                    $ci++
                }
            }
            # $c.scope.($PacSelectorName) = "/providers/Microsoft.Management/managementGroups/" + $NewManagementGroupName
            # Write-Information "    Updated Child $($c.nodeName)..."
            # $ci++
        }
    }
    if ($ci -gt 0) {
        Write-Information "    Updated $ci child nodes..."
        return
    }
    else {
        Write-Warning "No child nodes contain an assignment under PacSelectorName: $pacSelectorName using the  OldManagementGroupName $OldManagementGroupName...."
        Write-Information "You may need to simply add a new block rather than run this script..."
        return
    }
}
else {
    if ($assignmentData.scope.($PacSelectorName)) {
        foreach ($a in $assignmentData.scope.($PacSelectorName)) {
            if ($a -eq $("/providers/Microsoft.Management/managementGroups/" + $OldManagementGroupName)) {
                $a = "/providers/Microsoft.Management/managementGroups/" + $NewManagementGroupName
                Write-Information "    Updated $($assignmentData.nodeName)..."
                return
            }
        }
    }
    else {
        Write-Warning "No assignment found for $($PacSelectorName) in $($AssignmentFile), you may need to simply add a new block rather than run this script..."
        return
        
    }
}
# if ($assignmentData.Children.Count -gt 0) {
#     foreach ($c in $children) {
#         if ($c.scope.($PacSelectorName)) {
#             $childName = $c.scope.nodeName
#         }
#     }
#     if (!($childName)) {
#         Write-Warning "Child nodes found, but no child assignment found for $($PacSelectorName) in $($AssignmentFile), you may need to simply add a new block..."
#         return
#     }
# }
    
if (!($SuppressFileOutput)) {
    $regex = "policyAssignments(.*)"
    if ($AssignmentFile -match $regex) {
        $relativeFilePath = $matches[1].Replace('\', '/')
    }
    else {
        Write-Warning "File $AssignmentFile does not match the expected pattern, you should use an EPAC directory structure for this..."
        return
    }
    $outputFile = Join-Path $Output "UpdatedAssignmentDestination" "Definitions" "policyAssignments" $relativeFilePath
    if (!(Test-Path (Split-Path $outputFile))) {
        New-Item -ItemType Directory -Path (Split-Path $outputFile) | Out-Null
    }
    $assignmentData | ConvertTo-Json -Depth 100 | Set-Content -Path $outputFile
}
if (!($SuppressReturn)) {
    return $assignmentData
}
