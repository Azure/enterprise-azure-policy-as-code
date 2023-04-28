<#
.SYNOPSIS
    Flattens the policy file structure to a single folder.
#>

# Remove hidden files, like thumbs.db
$removeHiddenFiles = $true
# Get hidden files or not. Depending on removeHiddenFiles setting
$getHiddelFiles = !$removeHiddenFiles
# Remove empty directories locally

Function Remove-EmptyFolder($path) {
    # Go through each subfolder, 
    Foreach ($subFolder in Get-ChildItem -Force -Literal $path -Directory) {
        # Call the function recursively
        Remove-EmptyFolder -path $subFolder.FullName
    }
    # Get all child items
    $subItems = Get-ChildItem -Force:$getHiddelFiles -LiteralPath $path
    # If there are no items, then we can delete the folder
    # Exluce folder: If (($subItems -eq $null) -and (-Not($path.contains("DfsrPrivate")))) 
    If ($null -eq $subItems) {
        Remove-Item -Force -Recurse:$removeHiddenFiles -LiteralPath $Path -Verbose
    }
}

$fileSpec = "azurepolicy.json"
$rootDir = "C:\Src\SCaC\Policies"
Get-ChildItem $rootDir -recurse -include azurepolicy.*.json | Remove-Item -Verbose
Get-ChildItem $rootDir -recurse -include *.md | Remove-Item -Verbose
$fileList = Get-ChildItem -Path $rootDir -Filter $fileSpec -Recurse
foreach ($fileInfo in $fileList) {
    $fileName = $fileInfo.FullName
    $directoryName = Split-Path $fileName
    $newFileName = $directoryName + ".json"
    Move-Item $fileName -Destination $newFileName -Verbose
}

Remove-EmptyFolder -path $rootDir

