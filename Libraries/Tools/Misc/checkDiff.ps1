param (
    [Parameter(Mandatory = $true)][AllowEmptyString()]$defRootFolder,
    [Parameter(Mandatory = $true)][AllowEmptyString()]$folderName
)

# git dif finds modified polcies, initatiatives, or assignments
$path = $defRootFolder + $folderName
$filesInfo = git diff HEAD~ HEAD --name-status $path
Write-Host "Numbers of difs found: $($filesInfo.Count)"

# process each modified file and add to array.
$modifiedObjects = @()
$pathStart = $folderName + "/"
foreach ($fileInfo in $filesInfo) {
    $mainSplit = $fileInfo -split "\s", 2
    $changeType = $mainSplit[0]
    if ($changeType -eq "D") {
        Write-Host $fileInfo
    }
    else {
        $filePaths = ""
        $filePaths = $mainSplit[1]
        $filePath = ""
        $lastIndex = $filePaths.LastIndexOf($pathStart)
        $length = $filePaths.Length - $lastIndex
        if ($lastIndex -ne 0) {
            $filePath = $filePaths.SubString($lastIndex, $length)
        }
        else {
            $filePath = $filePaths
        }
        Write-Host "$fileInfo ===>> $filePath"

        $modifiedObjects += $filePath
    }
}

if ($modifiedObjects.Count -eq 0) {
    Write-Host "##vso[task.LogIssue type=warning;]No diffs found or only deleted files found, exiting..."
}
else {
    $uniqueModifiedObjects = $modifiedObjects | Sort-Object -Unique
    $uniqueModifiedObjectsJson = ($uniqueModifiedObjects | ConvertTo-Json -Compress).Trim("[", "]")

    Write-Host "Unique Objects: $uniqueModifiedObjects"
    # output pipeline variable to be consumed by subsequent pipeline tasks
    Write-Host "##vso[task.setvariable variable=$folderName]$uniqueModifiedObjectsJson"
}