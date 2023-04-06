function Get-PacFolders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string] $definitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $outputFolder,
        [Parameter(Mandatory = $false)] [string] $inputFolder
    )

    # Calculate folders
    if ($definitionsRootFolder -eq "") {
        if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
            $definitionsRootFolder = "Definitions"
        }
        else {
            $definitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
        }
    }
    $globalSettingsFile = "$definitionsRootFolder/global-settings.jsonc"

    if ($outputFolder -eq "") {
        if ($null -eq $env:PAC_OUTPUT_FOLDER) {
            $outputFolder = "Output"
        }
        else {
            $outputFolder = $env:PAC_OUTPUT_FOLDER
        }
    }

    if ($inputFolder -eq "") {
        if ($null -eq $env:PAC_INPUT_FOLDER) {
            $inputFolder = $outputFolder
        }
        else {
            $inputFolder = $env:PAC_INPUT_FOLDER
        }
    }

    $folders = @{
        definitionsRootFolder = $definitionsRootFolder
        globalSettingsFile    = $globalSettingsFile
        outputFolder          = $outputFolder
        inputFolder           = $inputFolder
    }

    return $folders
}