param (
    [Parameter(Mandatory=$true)][AllowEmptyString()]$defRootFolder,
    [Parameter(Mandatory=$true)][AllowEmptyString()]$folderName
)

$path = $defRootFolder + $folderName

# git dif finds modified polcies, initatiatives, or assignments
$files = git diff HEAD HEAD~ --name-only `
                             $path

if (!$files) {
    Write-Output "No diffs found, exiting..."
    Exit
}

$count = $files.Count

Write-Output "Numbers of difs found: $count"

$modifiedObjects = @()

# process each modified file and add to array
foreach ($file in $files) {
    Write-Output "Evaluating: $file"

    $record = ($file -split "/")

    $count = $record.Count

    $fileName = $record[$record.Count - 1]

    # Create-Initiative.ps1 and Create-Assignment.ps1 parameter is file name
    if ($record[0] -eq "Initiatives" -or $record[0] -eq "Assignments") {
        Write-Output "Initiative or Assignment has changed..."

        $modifiedObjects += $fileName -replace '\..*'
    }

    # Create-PolicyDef.ps1 parameter is dir names
    if ($record[0] -eq "Policies") {
        Write-Output "Policy has changed..."

        $trimPath = $file.TrimEnd($fileName)

        $modifiedObjects += $trimPath
    }
}

$uniqueModifiedObjects = $modifiedObjects | Sort-Object -Unique

$uniqueModifiedObjectsJson = ($uniqueModifiedObjects | ConvertTo-Json -Compress).Trim("[","]")

Write-Output "Unique Objects: $uniqueModifiedObjects"

# output pipeline variable to be consumed by subsequent pipeline tasks
Write-Output "##vso[task.setvariable variable=$folderName]$uniqueModifiedObjectsJson"