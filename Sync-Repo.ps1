<#
.SYNOPSIS
    Syncs a Repo of EPAC from/to the origin

.DESCRIPTION
    Syncs the sourceDirectory to the destinationDirectory
    * Folders
        * Docs
        * Module
        * Schemas
        * Scripts
        * StarterKit
    * Files in root folder ($sourceDirectory)
        * CODE_OF_CONDUCT.md
        * LICENSE
        * README.md
        * SECURITY.md
        * SUPPORT.md
        * Sync-Repo.ps1

.PARAMETER sourceDirectory
    Directory with the source (cloned or forked/cloned repo)

.PARAMETER destinationDirectory
    Directory with the destination (cloned or forked/cloned repo)

.PARAMETER suppressDeleteFiles
    Switch parameter to suppress deleting files in $destinationDirectory tree

.EXAMPLE
    Sync-Repo.ps1 -sourceDirectory "C:\Users\johndoe\Documents\GitHub\EPAC" -destinationDirectory "C:\Users\johndoe\Documents\GitHub\EPAC-Test"

#>
[CmdletBinding()]
param (
    # Directory with the source (cloned or forked/cloned repo)
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $sourceDirectory,

    # Directory with the destination (cloned or forked/cloned repo)
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $destinationDirectory,

    # Switch parameter to suppress deleting files in $destinationDirectory tree
    [Parameter()]
    [switch] $suppressDeleteFiles
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
        if (Test-Path "$destinationDirectory/Module") {
            Write-Information "Deleting '$destinationDirectory/Module'"
            Remove-Item "$destinationDirectory/Module" -Recurse
        }
        if (Test-Path "$destinationDirectory/Schemas") {
            Write-Information "Deleting '$destinationDirectory/Schemas'"
            Remove-Item "$destinationDirectory/Schemas" -Recurse
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

    Write-Information "Copying '$sourceDirectory/Docs' to '$destinationDirectory/Docs'"
    Copy-Item "$sourceDirectory/Docs" "$destinationDirectory/Docs" -Recurse -Force
    Write-Information "Copying '$sourceDirectory/Module' to '$destinationDirectory/Module'"
    Copy-Item "$sourceDirectory/Module" "$destinationDirectory/Module" -Recurse -Force
    Write-Information "Copying '$sourceDirectory/Schemas' to '$destinationDirectory/Schemas'"
    Copy-Item "$sourceDirectory/Schemas" "$destinationDirectory/Schemas" -Recurse -Force
    Write-Information "Copying '$sourceDirectory/Scripts' to '$destinationDirectory/Scripts'"
    Copy-Item "$sourceDirectory/Scripts" "$destinationDirectory/Scripts" -Recurse -Force
    Write-Information "Copying '$sourceDirectory/StarterKit' to '$destinationDirectory/StarterKit'"
    Copy-Item "$sourceDirectory/StarterKit" "$destinationDirectory/StarterKit" -Recurse -Force

    Write-Information "Copying files from root directory '$sourceDirectory' to '$destinationDirectory'"
    Copy-Item "$sourceDirectory/*.md" "$destinationDirectory"
    Copy-Item "$sourceDirectory/*.ps1" "$destinationDirectory"
    Copy-Item "$sourceDirectory/*.yml" "$destinationDirectory"
    Copy-Item "$sourceDirectory/LICENSE" "$destinationDirectory"
}
else {
    Write-Error "The source directory '$sourceDirectory' must exist" -ErrorAction Stop
}
