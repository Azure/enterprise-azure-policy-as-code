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
    $suppressDeleteFiles,

    # Switch parameter to exclude documentation files *.md, LICENSE from synchronization
    [Parameter()]
    [switch]
    $omitDocFiles
)

# Check if directories exist
if ((Test-Path $sourceDirectory -PathType Container) -and (Test-Path $destinationDirectory -PathType Container)) {
    if (!$suppressDeleteFiles.IsPresent) {
        # Delete $destinationDirectory directories prior to copy - removes obsolete files
        if (Test-Path "$destinationDirectory/Docs") {
            Remove-Item "$destinationDirectory/Docs" -Recurse
        }
        if (Test-Path "$destinationDirectory/Scripts") {
            Remove-Item "$destinationDirectory/Scripts" -Recurse
        }
        if (Test-Path "$destinationDirectory/StarterKit") {
            Remove-Item "$destinationDirectory/StarterKit" -Recurse
        }
    }

    Copy-Item "$sourceDirectory/Docs" "$destinationDirectory/Docs" -Recurse -Force
    Copy-Item "$sourceDirectory/Scripts" "$destinationDirectory/Scripts" -Recurse -Force
    Copy-Item "$sourceDirectory/StarterKit" "$destinationDirectory/StarterKit" -Recurse -Force

    if (!$omitDocFiles.IsPresent) {
        if (!(Test-Path "$destinationDirectory/Definitions")) {
            New-Item "$destinationDirectory/Definitions" -ItemType Directory
        }
        Copy-Item "$sourceDirectory/Definitions" "$destinationDirectory" -Filter README.md -Recurse -Force

        if (!(Test-Path "$destinationDirectory/Pipeline")) {
            New-Item "$destinationDirectory/Pipeline" -ItemType Directory
        }
        Copy-Item "$sourceDirectory/Pipeline" "$destinationDirectory" -Filter README.md -Recurse -Force

        Copy-Item "$sourceDirectory/CODE_OF_CONDUCT.md" "$destinationDirectory/CODE_OF_CONDUCT.md"
        Copy-Item "$sourceDirectory/LICENSE" "$destinationDirectory/LICENSE"
        Copy-Item "$sourceDirectory/README.md" "$destinationDirectory/README.md"
        Copy-Item "$sourceDirectory/SECURITY.md" "$destinationDirectory/SECURITY.md"
        Copy-Item "$sourceDirectory/SUPPORT.md" "$destinationDirectory/SUPPORT.md"
        Copy-Item "$sourceDirectory/Sync-Repo.ps1" "$destinationDirectory/Sync-Repo.ps1"
    }
}
else {
    Write-Error "The source '$sourceDirectory' and destination '$destinationDirectory' directories must exist"
}
