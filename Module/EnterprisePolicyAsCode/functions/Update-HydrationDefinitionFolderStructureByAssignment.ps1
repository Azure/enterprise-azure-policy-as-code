<#
.SYNOPSIS
    The Update-HydrationDefinitionFolderStructureByAssignment function processes policy set definitions and policy definitions from a specified directory, moves them based on their assignments, and logs the changes.

.DESCRIPTION
    
    This function adds a folder layer at the ./Definitions/policySetDefinitions and ./Definitions/policyDefinitions folder layers based on the ./Definitions/policyAssignments subdirectory structure.
    Each definition will be copied to an output structure to reflect the structure used in assignments. This is to assist with security structure, such as use of GitHub Code Owners. 
    If a definition is not assigned, either directly or via a policySetDefinition, it will be placed in the root of the Unused subfolder. This will assist with cleanup and organization.

.PARAMETER Definitions
    The path to the directory containing the policy set definitions and policy definitions. The default is "./Definitions".

.PARAMETER Output
    The path to the directory where the output will be saved. The default is "./Output".

.PARAMETER FolderOrder
    An ordered hashtable specifying the order of the folders.

.EXAMPLE
    $myFolderOder = [ordered]@{
        SecurityOperations = "security"
        HRProtected        = "hr"
        FinanceTracking    = "finance"
        PlatformOperations = "platform"
    }
    Update-HydrationDefinitionFolderStructureByAssignment -Definitions "./Definitions" -Output "./Output" -FolderOrder $myFolderOrder

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function Update-HydrationDefinitionFolderStructureByAssignment {
    param (
        [Parameter(Mandatory = $false, HelpMessage = "The path to the directory containing the policy set definitions and policy definitions. The default is './Definitions'.")]
        [string]
        $Definitions = "./Definitions",

        [Parameter(Mandatory = $false, HelpMessage = "The path to the directory where the output will be saved. The default is './Output'.")]
        [string]
        $Output = "./Output",

        [Parameter(Mandatory = $true, HelpMessage = "An ordered hashtable specifying the order of the folders.")]
        [System.Management.Automation.OrderedHashtable]
        $FolderOrder
    ) 
    $InformationPreference = "Continue"
    # TODO: Add a reporting feature to use the keys for Folder Order as organization internal values that tie to the approval folders in GitHub Owners for output logs.
    $psdList = Get-ChildItem $(Join-Path $Definitions "policySetDefinitions") -recurse -file -include "*.json", "*.jsonc"
    $pdList = Get-ChildItem $(Join-Path $Definitions "policyDefinitions") -recurse -file -include "*.json", "*.jsonc"
    Write-Debug "Policy Set Definition Count: $($psdList.Count)"
    Write-Debug "Policy Set Count: $($pdList.Count)"
    $ChangeLogData = [ordered]@{
    }
    Write-Information "Processing $($psdList.Count) Policy Set Definitions..."
        
    foreach ($psd in $psdList) {
        Write-Debug "Processing $($psd.Name)..."
        $outInfo = Copy-DefinitionByAssignment -PolicyPath $psd.FullName -FolderOrder $FolderOrder -Definitions $Definitions -Output $Output -ChangeLogData:$ChangeLogData
        if ($outInfo) {
            $ChangeLogData.Add($psd.FullName, $outInfo)
        }
        else {
            Write-Warning "    No return from Move-DefinitionByPolicyAssignment for $($psd.Name)"
        }
    }
    $psdProcessedCount = $ChangeLogData.Keys.Count
    Write-Information "Classified $psdProcessedCount Policy Set Definitions..."
    $newPsdFolder = @{
        Path                = $Output
        ChildPath           = "NewFolderStructure"
        AdditionalChildPath = "policySetDefinitions"
    }
    $newPsdPath = Join-Path @newPsdFolder
    $newPsdList = Get-ChildItem $newPsdPath -recurse -file -include "*.json", "*.jsonc"
    Write-Information "$newPsdPath File Count: $($newPsdList.Count)"
    ## Begin Processing Policy Definitions
    Write-Information "Processing $($pdList.Count) Policy Definitions..."
    foreach ($pd in $pdList) {
        Write-Debug "Processing $($pd.Name)..."
        $outInfo = Copy-DefinitionByAssignment -PolicyPath $pd.FullName -FolderOrder $FolderOrder -Definitions $Definitions -Output $Output -ChangeLogData:$ChangeLogData
        if ($outInfo) {
            $ChangeLogData.Add($pd.FullName, $outInfo)
        }
        else {
            Write-Warning "    No return from Move-DefinitionByPolicyAssignment for $($pd.Name)"
        }
    }
    $pdProcessedCount = $ChangeLogData.Keys.Count - $psdProcessedCount
    Write-Information "Classified $pdProcessedCount Policy Set Definitions..."
    $newPdFolder = @{
        Path                = $Output
        ChildPath           = "NewFolderStructure"
        AdditionalChildPath = "policyDefinitions"
    }
    $newPdPath = Join-Path @newPdFolder
    $newPdList = Get-ChildItem $newPdPath -recurse -file -include "*.json", "*.jsonc"
    Write-Information "$newPdPath File Count: $($newPdList.Count)"
    $outputFile = @{
        Path                = $Output
        ChildPath           = "NewFolderStructure"
        AdditionalChildPath = "ChangeLog.json"
    }
    $outputFilePath = Join-Path @outputFile
    if (!(Test-Path $(Split-Path $outputFilePath))) {
        $null = New-Item -Path $(Split-Path $outputFilePath) -ItemType Directory -Force
    }
    $ChangeLogData | Export-HydrationObjectToJsonFile -OutputFilePath $outputFilePath
    if (Test-Path $outputFilePath) {
        Write-Information "Change Log saved to $outputFilePath"
    }
    else {
        Write-Warning "Failed to create log at $outputFilePath"
    }
}