function Get-PacFolders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string] $DefinitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $OutputFolder,
        [Parameter(Mandatory = $false)] [string] $InputFolder
    )

    # Calculate folders
    if ($DefinitionsRootFolder -eq "") {
        if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
            $DefinitionsRootFolder = "Definitions"
        }
        else {
            $DefinitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
        }
    }
    $globalSettingsFile = "$DefinitionsRootFolder/global-settings.jsonc"

    if ($OutputFolder -eq "") {
        if ($null -eq $env:PAC_OUTPUT_FOLDER) {
            $OutputFolder = "Output"
        }
        else {
            $OutputFolder = $env:PAC_OUTPUT_FOLDER
        }
    }

    if ($InputFolder -eq "") {
        if ($null -eq $env:PAC_INPUT_FOLDER) {
            $InputFolder = $OutputFolder
        }
        else {
            $InputFolder = $env:PAC_INPUT_FOLDER
        }
    }

    $folders = @{
        definitionsRootFolder = $DefinitionsRootFolder
        globalSettingsFile    = $globalSettingsFile
        outputFolder          = $OutputFolder
        inputFolder           = $InputFolder
    }

    return $folders
}
