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
    * Files in root folder ($SourceDirectory)
        * CODE_OF_CONDUCT.md
        * LICENSE
        * README.md
        * SECURITY.md
        * SUPPORT.md
        * Sync-Repo.ps1

.PARAMETER SourceDirectory
    Directory with the source (cloned or forked/cloned repo)

.PARAMETER DestinationDirectory
    Directory with the destination (cloned or forked/cloned repo)

.PARAMETER SuppressDeleteFiles
    Switch parameter to suppress deleting files in $DestinationDirectory tree

.EXAMPLE
    Sync-Repo.ps1 -SourceDirectory "C:\Users\johndoe\Documents\GitHub\EPAC" -DestinationDirectory "C:\Users\johndoe\Documents\GitHub\EPAC-Test"

#>
[CmdletBinding()]
param (
    # Directory with the source (cloned or forked/cloned repo)
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $SourceDirectory,

    # Directory with the destination (cloned or forked/cloned repo)
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $DestinationDirectory,

    # Switch parameter to suppress deleting files in $DestinationDirectory tree
    [Parameter()]
    [switch] $SuppressDeleteFiles
)

$InformationPreference = "Continue"

Write-Information "==================================================================================================="
Write-Information "Sync from '$SourceDirectory' to '$DestinationDirectory'"
Write-Information "==================================================================================================="

# Check if directories exist
if (Test-Path $SourceDirectory -PathType Container) {
    if (!(Test-Path $DestinationDirectory -PathType Container)) {
        $answer = $null
        while ($answer -ne "y" -and $answer -ne 'n') {
            $answer = Read-Host "Destination directory '$DestinationDirectory' does not exist. Create it (y/n)?"
        }
        if ($answer -eq "y") {
            New-Item "$DestinationDirectory" -ItemType Directory
        }
        else {
            Write-Error "Destination directory '$DestinationDirectory' does not exist - Exiting" -ErrorAction Stop
        }
    }

    if (!($SuppressDeleteFiles)) {
        if (Test-Path "$DestinationDirectory/Docs") {
            Write-Information "Deleting '$DestinationDirectory/Docs'"
            Remove-Item "$DestinationDirectory/Docs" -Recurse
        }
        if (Test-Path "$DestinationDirectory/Module") {
            Write-Information "Deleting '$DestinationDirectory/Module'"
            Remove-Item "$DestinationDirectory/Module" -Recurse
        }
        if (Test-Path "$DestinationDirectory/Schemas") {
            Write-Information "Deleting '$DestinationDirectory/Schemas'"
            Remove-Item "$DestinationDirectory/Schemas" -Recurse
        }
        if (Test-Path "$DestinationDirectory/Scripts") {
            Write-Information "Deleting '$DestinationDirectory/Scripts'"
            Remove-Item "$DestinationDirectory/Scripts" -Recurse
        }
        if (Test-Path "$DestinationDirectory/StarterKit") {
            Write-Information "Deleting '$DestinationDirectory/StarterKit'"
            Remove-Item "$DestinationDirectory/StarterKit" -Recurse
        }
    }

    Write-Information "Copying '$SourceDirectory/Docs' to '$DestinationDirectory/Docs'"
    Copy-Item "$SourceDirectory/Docs" "$DestinationDirectory/Docs" -Recurse -Force
    Write-Information "Copying '$SourceDirectory/Module' to '$DestinationDirectory/Module'"
    Copy-Item "$SourceDirectory/Module" "$DestinationDirectory/Module" -Recurse -Force
    Write-Information "Copying '$SourceDirectory/Schemas' to '$DestinationDirectory/Schemas'"
    Copy-Item "$SourceDirectory/Schemas" "$DestinationDirectory/Schemas" -Recurse -Force
    Write-Information "Copying '$SourceDirectory/Scripts' to '$DestinationDirectory/Scripts'"
    Copy-Item "$SourceDirectory/Scripts" "$DestinationDirectory/Scripts" -Recurse -Force
    Write-Information "Copying '$SourceDirectory/StarterKit' to '$DestinationDirectory/StarterKit'"
    Copy-Item "$SourceDirectory/StarterKit" "$DestinationDirectory/StarterKit" -Recurse -Force

    Write-Information "Copying files from root directory '$SourceDirectory' to '$DestinationDirectory'"
    Copy-Item "$SourceDirectory/*.md" "$DestinationDirectory"
    Copy-Item "$SourceDirectory/*.ps1" "$DestinationDirectory"
    Copy-Item "$SourceDirectory/*.yml" "$DestinationDirectory"
    Copy-Item "$SourceDirectory/LICENSE" "$DestinationDirectory"
}
else {
    Write-Error "The source directory '$SourceDirectory' must exist" -ErrorAction Stop
}
