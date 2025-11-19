function Copy-DefinitionByAssignment {
    <#
    .SYNOPSIS
        This function creates a copy of a policy or policySet definition by assignment in a specified location based on the location of the Assignment that references it.

    .DESCRIPTION
        The Copy-DefinitionByAssignment function processes a definition from a specified path, copies it based on its assignment, and logs the changes.
        If multiple assignments are found, the highest priority folder will be used as specified in the FolderOrder hashtable.
        This is generally used to aid in securing the repository, such as for use with GitHub Code Owners.
        This can also be used to identify unused definitions, as they will be placed in the Unused subfolder.

    .PARAMETER PolicyPath
        The path to the policy or policySet definition file. This parameter is mandatory.

    .PARAMETER FolderOrder
        An ordered hashtable specifying the order of the folders.

    .PARAMETER Definitions
        The path to the directory containing the policy definitions. The default is "./Definitions".

    .PARAMETER Output
        The path to the directory where the output will be saved. The default is "./Output".

    .PARAMETER SuppressFileCopy
        A switch parameter. If specified, the function will not copy the policy definition file.

    .PARAMETER ChangeLogData
        An ordered hashtable for logging changes. This parameter is optional, but is necessary for the review against decisions made on previously processed policySetDefinitions when processing policyDefinitions.

    .EXAMPLE
        $myFolderOder = [ordered]@{
            SecurityOperations = "security"
            HRProtected        = "hr"
            FinanceTracking    = "finance"
            PlatformOperations = "platform"
        }
        Copy-DefinitionByAssignment -PolicyPath "./Definitions/policySetDefinitions/MyPolicy.json" -FolderOrder $myFolderOrder -ChangeLogData:$ChangeLogData
        Processes the policySet definition in the "MyPolicy.json", and copies it to a location in ./Output/NewFolderStructure based on its assignment (or lack thereof) according to the $myFolderOrder hashtable.
        If it is found in a policyAssignment, the containing folder for the assignment in $myFolderOrder will be used. If it is not found, it will be placed in the Unused subfolder.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $PolicyPath,
        [System.Management.Automation.OrderedHashtable]
        $FolderOrder,
        [string]
        $Definitions = "./Definitions",
        [string]
        $Output = "./Output",
        [switch]
        $SuppressFileCopy,
        [System.Management.Automation.OrderedHashtable]
        [Parameter(Mandatory = $false)]
        $ChangeLogData
    )
    $InformationPreference = "Continue"
    $defaultCategory = "Unused"
    $OutputPath = Join-Path $Output "NewFolderStructure"
    if (!(Test-Path $OutputPath)) {
        $null = New-Item -Path $OutputPath -ItemType Directory -Force
    }    
    $OutputPath = Resolve-Path $OutputPath
    if ($PolicyPath -like "*policySetDefinitions*") {
        $definitionType = "policySetDefinitions"
    }
    elseif ($PolicyPath -like "*policyDefinitions*") {
        $definitionType = "policyDefinitions"
    }
    else {
        Write-Error "PolicySetPath $($PolicyPath) is not part of a valid folder structure for EPAC Definitions."
        return
    }
    If (Test-Path $PolicyPath) {
        $PolicyContent = Get-Content -Path $PolicyPath | ConvertFrom-Json -Depth 100
    }
    else {
        Write-Error "PolicySetPath $($PolicyPath) does not exist."
        return
    }
    Write-Debug "Processing $($PolicyPath)..."
    Write-Debug "    PolicySet.Name $($PolicyContent.Name)"
    if ($PolicyPath -like "*policySetDefinitions*") {
        $definitionType = "policySetDefinitions"
    }
    elseif ($PolicyPath -like "*policyDefinitions*") {
        $definitionType = "policyDefinitions"
    }
    else {
        Write-Error "PolicySetPath $($PolicyPath) is not part of a valid folder structure for EPAC Definitions."
        return
    }
    Write-Debug "    DefinitionType $definitionType"
    $pAssignmentCopyRecord = [ordered]@{
        SourceFile          = $PolicyPath
        NewFilePath         = ""
        AssignmentFile      = ""
        ParentPolicySetFile = ""
        Status              = ""
        RecordType          = $definitionType
        Found               = "False"
        AlreadyCategorized  = "False"
        AssignmentSubfolder = ""
        SecurityRootPath    = ""
        CurrentOutputPath   = ""
        InitialRelativePath = ""
    }
    ## PROCESS POLICY SETS
    ## Test all assignments that are in this category to see if they contain the policySet.
    foreach ($f2 in $FolderOrder.Values) {
        ## Confirm the path doesn't already include a folder in the FolderOrder list, must be accounted for in relative path string.
        foreach ($f3 in $FolderOrder.Values) {
            if ($PolicyPath -like "*/$f3/*" -or $PolicyPath -like "*\$f3\*") {
                $pAssignmentCopyRecord.AlreadyCategorized = $f3
            }
        }
        Remove-Variable f3
        Write-Debug "    Testing folder $f2 for assignments..."
        $assignmentRoot = @{
            Path                = $Definitions
            ChildPath           = "policyAssignments"
            AdditionalChildPath = $f2
        }
        $assignmentRootPath = Join-Path @assignmentRoot
        if (!(Test-Path $assignmentRootPath)) {
            Write-Warning "The path $assignmentRootPath is invalid, and will occur if you do not have all items in FolderOrder represented in policySetDefinitions. This can be normal while the initial buildout is being completed."
            if (!($(Test-Path (Split-Path (Split-Path $assignmentRootPath))) -eq "Definitions")) {
                Write-Error "No Definitions folder found. Location `"$Definitions`" is not part of a valid EPAC repository structure."
                break
            }
            else {
                Write-Debug "No assignments found in $assignmentRootPath"
                continue
            }
        }
        else {
            $policyAssignments = Get-ChildItem -Path $assignmentRootPath -Recurse -File -Include "*.json", "*.jsonc" -ErrorAction SilentlyContinue
        }
        if (!($policyAssignments) -or !($policyAssignments.count -gt 0)) {
            Write-Debug "No assignments found in $assignmentRootPath"
            continue
        }
        foreach ($a in $policyAssignments) {
            $pAssignmentCopyRecord.AssignmentSubfolder = Get-HydrationDefinitionSubfolderByContentId -ContentId $PolicyContent.Name -ContainerDefinitionPath $a.FullName -CategoryList:$ChangeLogData
            if ($pAssignmentCopyRecord.AssignmentSubfolder -ne "NotFound") {
                $pAssignmentCopyRecord.AssignmentFile = $a.FullName
                $pAssignmentCopyRecord.Status = "Active"
                $pAssignmentCopyRecord.Found = "True"
                break
            }
        }
        remove-variable a
        if ($PolicyPath -like "*\*") {
            $pAssignmentCopyRecord.InitialRelativePath = $(Split-Path $PolicyPath) -replace ".*\\$($pAssignmentCopyRecord.RecordType)\\", ''
        }
        else {
            $pAssignmentCopyRecord.InitialRelativePath = $(Split-Path $PolicyPath) -replace ".*\/$($pAssignmentCopyRecord.RecordType)\/", ''
        }
        $currentOutputPath = @{
            Path                = $OutputPath
            ChildPath           = $pAssignmentCopyRecord.RecordType
            AdditionalChildPath = $pAssignmentCopyRecord.AssignmentSubfolder
        }
        $pAssignmentCopyRecord.CurrentOutputPath = Join-Path @currentOutputPath
        if ($pAssignmentCopyRecord.Found -ne "True") {
            $pAssignmentCopyRecord.Status = "Inactive"
            $pAssignmentCopyRecord.Found = "False"
            $pAssignmentCopyRecord.AssignmentSubfolder = $defaultCategory
            $pAssignmentCopyRecord.AssignmentFile = "None"
        }
        if ($pAssignmentCopyRecord.ParentPolicySetFile -eq "") {
            $pAssignmentCopyRecord.ParentPolicySetFile = "None"
        }
        Write-Debug "    Copy Source: $($PolicyPath)"
        if ($pAssignmentCopyRecord.Found -eq "True") {
            break
        }
        # TODO: INSERT DEBUG BLOCK
    }
    if ($definitionType -eq "policySetDefinitions") {
        $securityRootPath = @{
            Path                = $OutputPath
            ChildPath           = $pAssignmentCopyRecord.RecordType
            AdditionalChildPath = $pAssignmentCopyRecord.AssignmentSubfolder
        }
        $pAssignmentCopyRecord.SecurityRootPath = Join-Path @securityRootPath
        $currentOutputPath = @{
            Path      = $pAssignmentCopyRecord.SecurityRootPath
            ChildPath = $pAssignmentCopyRecord.InitialRelativePath
        }
        $pAssignmentCopyRecord.CurrentOutputPath = Join-Path @currentOutputPath
        $newFilePath = @{
            Path      = $pAssignmentCopyRecord.CurrentOutputPath
            ChildPath = $pAssignmentCopyRecord.Name
        }
        $pAssignmentCopyRecord.NewFilePath = Join-Path @NewFilePath
        Remove-Variable securityRootPath         
        Remove-Variable currentOutputPath
        Remove-Variable newFilePath
        Write-Debug "    Copy Destination: $($pAssignmentCopyRecord.NewFilePath)"
        Write-Debug "    Assignment File: $($pAssignmentCopyRecord.AssignmentFile)"
        if (!($SuppressFileCopy)) {
            if (!(Test-Path $pAssignmentCopyRecord.CurrentOutputPath)) {
                $null = New-Item -Path $pAssignmentCopyRecord.CurrentOutputPath -ItemType Directory -Force
            }
            Copy-Item -Path $PolicyPath -Destination $pAssignmentCopyRecord.CurrentOutputPath
        }
        return $pAssignmentCopyRecord
        # END PROCESSING OF POLICYSETS
    }
    else {
        # We search all policySetDefinitions as a group, and do not use folder structure as  it has no RoI here. 
        # We have already processed them, and will use the data collected from that process if a link is found.
        $psdRootPath = Join-Path $Definitions "policySetDefinitions"
        $policySetDefinitions = Get-ChildItem -Path $psdRootPath -Recurse -File -Include "*.json", "*.jsonc" -ErrorAction SilentlyContinue
        if (!($policySetDefinitions) -or !($policySetDefinitions.count -gt 0)) {
            Write-Information "No Policy Set Definitions found in $psdRootPath"
        }
        else {
            if ($PolicyPath -like "*\*") {
                $pdInitialRelativePath = $(Split-Path $PolicyPath) -replace ".*\\$($pAssignmentCopyRecord.RecordType)\\", ''
            }
            else {
                $pdInitialRelativePath = $(Split-Path $PolicyPath) -replace ".*\/$($pAssignmentCopyRecord.RecordType)\/", ''
            }
            foreach ($psd in $policySetDefinitions) {
                $psdContent = Get-Content -Path $psd.FullName | ConvertFrom-Json -Depth 100
                $parentCopyRecord = [ordered]@{
                    SourceFile          = $PolicyPath
                    NewFilePath         = ""
                    AssignmentFile      = ""
                    ParentPolicySetFile = ""
                    Status              = ""
                    RecordType          = $definitionType
                    Found               = "False"
                    AlreadyCategorized  = "False"
                    AssignmentSubfolder = ""
                    SecurityRootPath    = ""
                    CurrentOutputPath   = ""
                    InitialRelativePath = $pdInitialRelativePath
                }
                if ($psdContent.properties.policyDefinitions.policyDefinitionName -contains $PolicyContent.Name -and $ChangeLogData) {      
                    foreach ($c in $ChangeLogData.GetEnumerator()) {
                        if ($c.Value.SourceFile -eq $psd.FullName) {
                            $parentCopyRecord.SourceFile = $PolicyPath
                            $parentCopyRecord.AssignmentFile = $c.Value.AssignmentFile
                            $parentPolicySetFile = @{
                                Path      = $c.Value.NewFilePath
                                ChildPath = $(Split-Path $c.Value.SourceFile -Leaf)
                            }
                            $parentCopyRecord.ParentPolicySetFile = Join-Path @parentPolicySetFile
                            $parentCopyRecord.Status = $c.Value.Status
                            $parentCopyRecord.Found = $c.Value.Found
                            $parentCopyRecord.AssignmentSubfolder = $c.Value.AssignmentSubfolder
                            break
                        }
                    }
                    Write-Debug "    ParentPolicySetFile $($parentCopyRecord.ParentPolicySetFile)"
                }
            }
            Remove-Variable psd
            ## TODO: INSERT DEBUG BLOCK
        }
        if (($pAssignmentCopyRecord.Found -eq "True" -and $parentCopyRecord.Found -eq "True")) {   
            Write-Debug "PolicySet Assignment and Policy Assignment Found"
            if ($pAssignmentCopyRecord.OutputPath -eq $parentCopyRecord.OutputPath) {
                # If BOTH are found, and equal in terms of security, one must be chosen arbitrarily
                $useRecord = $pAssignmentCopyRecord
            }
            elseif ($parentCopyRecord.AssignmentSubfolder -eq $defaultCategory) {
                $useRecord = $pAssignmentCopyRecord
            }
            elseif ($pAssignmentCopyRecord.AssignmentSubfolder -eq $defaultCategory) {
                $useRecord = $parentCopyRecord
            }
            else {
                if ([array]::IndexOf($($FolderOrder.Values, $pAssignmentCopyRecord.AssignmentSubfolder)) -gt $([array]::IndexOf($FolderOrder.Values, $parentCopyRecord.AssignmentSubfolder))) {
                    $useRecord = $pAssignmentCopyRecord
                }
                else {
                    $useRecord = $parentCopyRecord
                }
            }
        }
        elseif ($pAssignmentCopyRecord.Found -eq "True" -or ($parentCopyRecord.Found -ne "True" -and $pAssignmentCopyRecord.Found -ne "True")) {     
            # If Neither are found, one must be chosen arbitrarily
            $useRecord = $pAssignmentCopyRecord
        }
        elseif ($parentCopyRecord.Found -eq "True") {
            $useRecord = $parentCopyRecord
        }
        else {
            Write-Error "This should never happen. $PolicyPath was neither found, nor unfound."
        }
        $securityRootPath = @{
            "Path"                = $OutputPath
            "ChildPath"           = $useRecord.RecordType
            "AdditionalChildPath" = $useRecord.AssignmentSubfolder
        }
        $useRecord.SecurityRootPath = Join-Path @securityRootPath
        $currentOutputPath = @{
            "Path"      = $useRecord.SecurityRootPath
            "ChildPath" = $useRecord.InitialRelativePath
        }
        $useRecord.CurrentOutputPath = Join-Path @currentOutputPath
        $NewFilePath = @{
            "Path"      = $useRecord.CurrentOutputPath
            "ChildPath" = $useRecord.Name
        }
        $useRecord.NewFilePath = Join-Path @NewFilePath

        Write-Debug "    Copy Source: $($PolicyPath)"
        Write-Debug "    Creating Destination: $($useRecord.NewFilePath)"
        Write-Debug "    Assignment File: $($useRecord.AssignmentFile)"
        if (!($SuppressFileCopy)) {
            if (!(Test-Path $useRecord.CurrentOutputPath)) {
                $null = New-Item -Path $useRecord.CurrentOutputPath -ItemType Directory -Force
            }
            Copy-Item -Path $PolicyPath -Destination $useRecord.CurrentOutputPath
        }
        return $useRecord
    }
}
    