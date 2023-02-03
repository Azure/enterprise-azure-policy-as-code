#Requires -PSEdition Core

function Get-DefinitionsFullPath {
    [CmdletBinding()]
    param (
        $folder,
        $rawSubFolder,
        $name,
        $displayName,
        $invalidChars,
        $maxLengthSubFolder,
        $maxLengthFileName
    )

    $subFolder = Get-ScrubbedString -string $rawSubFolder -invalidChars $invalidChars -maxLength $maxLengthSubFolder -trimEnds -singleReplace
    if ($subFolder.Length -eq 0) {
        $subFolder = "Unknown"
    }

    $ObjectGuid = [System.Guid]::empty
    $isGuid = [System.Guid]::TryParse($name, [System.Management.Automation.PSReference]$ObjectGuid)
    $fileName = Get-ScrubbedString -string $name -invalidChars $invalidChars -replaceWith "" -replaceSpaces -replaceSpacesWith "-" -maxLength $maxLengthFileName -trimEnds -toLower -singleReplace
    if ($isGuid) {
        # try to avoid GUID file names
        if ($null -ne $displayName -and $displayName.Length -gt 0) {
            $fileNameTemp = $displayName
            $fileNameTemp = Get-ScrubbedString -string $fileNameTemp -invalidChars $invalidChars -replaceWith "" -replaceSpaces -replaceSpacesWith "-" -maxLength $maxLengthFileName -trimEnds -toLower -singleReplace
            if ($fileNameTemp.Length -gt 0) {
                $fileName = $fileNameTemp
            }
        }
    }
    $fullPath = "$folder/$subFolder/$($fileName).jsonc"

    return $fullPath
}