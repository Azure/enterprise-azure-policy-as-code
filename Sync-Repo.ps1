<#
.SYNOPSIS
    Syncs a Repo of EPAC from/to the origin
.DESCRIPTION
    Syncs the sourceDirectory to the destinationDirectory
    * Folders
        * Docs
        * Scripts
        * StarterKit
    * Files
        * Files (recursive) in Definitions, Pipeline folder
            * README.md
        * Files in root folder ($sourceDirectory)
            * CODE_OF_CONDUCT.md
            * LICENSE
            * README.md
            * SECURITY.md
            * SUPPORT.md
            * Sync-Repo.ps1
#>
[CmdletBinding()]
param (
    # Directory with the source (cloned or forked/cloned repo)
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $sourceDirectory,

    # Directory with the destination (cloned or forked/cloned repo)
    [Parameter(Mandatory = $true, Position = 1)]
    [string]
    $destinationDirectory,

    # Switch parameter to suppress deleting files in $destinationDirectory tree
    [Parameter()]
    [switch]
    $suppressDeleteFiles
)

$InformationPreference = "Continue"

Write-Information "==================================================================================================="
Write-Information "Sync from '$sourceDirectory' to '$destinationDirectory'"
Write-Information "==================================================================================================="

# Check if directories exist
if (Test-Path $sourceDirectory -PathType Container) {
    if (!(Test-Path $destinationDirectory -PathType Container)) {
        $answer = $null
        while ($answer -ne "y" -and $answer -ne 'n') {
            $answer = Read-Host "Destination directory '$destinationDirectory' does not exist. Create it (y/n)?"
        }
        if ($answer -eq "y") {
            New-Item "$destinationDirectory" -ItemType Directory
        }
        else {
            Write-Error "Destination directory '$destinationDirectory' does not exist - Exiting" -ErrorAction Stop
        }
    }

    if (!($suppressDeleteFiles)) {
        if (Test-Path "$destinationDirectory/Docs") {
            Write-Information "Deleting '$destinationDirectory/Docs'"
            Remove-Item "$destinationDirectory/Docs" -Recurse
        }
        if (Test-Path "$destinationDirectory/Scripts") {
            Write-Information "Deleting '$destinationDirectory/Scripts'"
            Remove-Item "$destinationDirectory/Scripts" -Recurse
        }
        if (Test-Path "$destinationDirectory/StarterKit") {
            Write-Information "Deleting '$destinationDirectory/StarterKit'"
            Remove-Item "$destinationDirectory/StarterKit" -Recurse
        }
    }

    Write-Information "Copying '$sourceDirectory/Docs'"
    Copy-Item "$sourceDirectory/Docs" "$destinationDirectory/Docs" -Recurse -Force
    Write-Information "Copying '$sourceDirectory/Scripts'"
    Copy-Item "$sourceDirectory/Scripts" "$destinationDirectory/Scripts" -Recurse -Force
    Write-Information "Copying '$sourceDirectory/StarterKit'"
    Copy-Item "$sourceDirectory/StarterKit" "$destinationDirectory/StarterKit" -Recurse -Force

    Write-Information "Copying documentation files from '$sourceDirectory'"
    Copy-Item "$sourceDirectory/CODE_OF_CONDUCT.md" "$destinationDirectory/CODE_OF_CONDUCT.md"
    Copy-Item "$sourceDirectory/LICENSE" "$destinationDirectory/LICENSE"
    Copy-Item "$sourceDirectory/README.md" "$destinationDirectory/README.md"
    Copy-Item "$sourceDirectory/SECURITY.md" "$destinationDirectory/SECURITY.md"
    Copy-Item "$sourceDirectory/SUPPORT.md" "$destinationDirectory/SUPPORT.md"
    Copy-Item "$sourceDirectory/Sync-Repo.ps1" "$destinationDirectory/Sync-Repo.ps1"
}
else {
    Write-Error "The source directory '$sourceDirectory' must exist" -ErrorAction Stop
}
