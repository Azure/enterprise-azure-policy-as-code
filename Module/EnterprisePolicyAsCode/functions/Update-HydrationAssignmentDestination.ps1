<#
.SYNOPSIS
    Updates the assignment destination in the given assignment file.

.DESCRIPTION
    The Update-HydrationAssignmentDestination function updates the assignment destination in the specified assignment file. 
    It allows you to provide a new management group name, prefix, or suffix to update the name of the management group destination.
    New Management Group assignments are generally used when items are moving within the hierarchy, such as when replacing a current hierarchy with a CAF3 hierarchy that utilizes the standard naming convention.
    The suffix and prefix are generally used in conjunction with similar name modification options used when cloning a hierarchy.


.PARAMETER PacSelectorName
    The name of the PAC selector to update. This parameter is mandatory.

.PARAMETER AssignmentFile
    The path to the assignment file to update. This parameter is mandatory.

.PARAMETER OldManagementGroupName
    The current name of the management group destination. This parameter is mandatory.

.PARAMETER NewManagementGroupName
    The new name for the management group destination. This parameter is mandatory when using the 'Static' parameter set.

.PARAMETER NewManagementGroupPrefix
    The new prefix for the management group destination. This parameter is optional and used in the 'Dynamic' parameter set.

.PARAMETER NewManagementGroupSuffix
    The new suffix for the management group destination. This parameter is optional and used in the 'Dynamic' parameter set.

.PARAMETER SuppressReturn
    Suppresses the return of the updated assignment data. This parameter is optional.

.PARAMETER Output
    The path to the output directory where the updated assignment file will be saved. Default is "./Output". This parameter is optional.

.PARAMETER SuppressFileOutput
    Suppresses the output of the updated assignment file. This parameter is optional.

.EXAMPLE
    Update-HydrationAssignmentDestination -PacSelectorName "MyPacSelector" -AssignmentFile "C:\path\to\assignment.json" -OldManagementGroupName "OldMGName" -NewManagementGroupName "NewMGName"

    This example updates the assignment destination in the "assignment.json" file by replacing the management group name "OldMGName" with "NewMGName".

.NOTES
    The function assumes that the assignment file is in JSON format. It reads the file, updates the management group destination, and optionally writes the updated content to a new file.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>

function Update-HydrationAssignmentDestination {
    [CmdletBinding(DefaultParameterSetName = 'Static')]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The name of the PAC selector to update.")]
        [string]
        $PacSelectorName,
        [Parameter(Mandatory = $true, HelpMessage = "The path to the assignment file to update.")]
        [string]
        $AssignmentFile,
        [Parameter(Mandatory = $true, HelpMessage = "The current name of the management group destination.")]
        [string]
        $OldManagementGroupName,
        [Parameter(Mandatory = $true, HelpMessage = "The new name for the management group destination.")]
        [string]
        $NewManagementGroupName,
        [Parameter(Mandatory = $false, HelpMessage = "The new prefix for the management group destination.")]
        [string]
        $NewManagementGroupPrefix,
        [Parameter(Mandatory = $false, HelpMessage = "The new suffix for the management group destination.")]
        [string]
        $NewManagementGroupSuffix,
        [Parameter(Mandatory = $false, HelpMessage = "Suppresses the return of the updated assignment data.")]
        [switch]
        $SuppressReturn,
        [Parameter(Mandatory = $false, HelpMessage = "The path to the output directory where the updated assignment file will be saved. Default is './Output'.")]
        [string]
        $Output = "./Output",
        [Parameter(Mandatory = $false, HelpMessage = "Suppresses the output of the updated assignment file.")]
        [switch]
        $SuppressFileOutput
    )
    # TODO: To process release flows, we'll need to be able to add multiple destinations. Add a loop to handle everything after the epac-dev and main, and allow option to specify if main will be used as source for hierarchy buildout in each pacselector or leave as is.
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
                    if ($a -eq $oldManagementGroupProvider) {
                        $a = "/providers/Microsoft.Management/managementGroups/" + $NewManagementGroupName
                        Write-Information "    Updated Child $($c.nodeName)..."
                        $ci++
                    }
                }
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

}