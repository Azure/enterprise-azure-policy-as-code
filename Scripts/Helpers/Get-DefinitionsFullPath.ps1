function Get-DefinitionsFullPath {
    [CmdletBinding()]
    param (
        $folder,
        $rawSubFolder = $null,
        $fileSuffix = "",
        $name,
        $displayName,
        $invalidChars,
        $maxLengthSubFolder,
        $maxLengthFileName,
        $fileExtension
    )

    $subFolder = "Unknown"
    if ($null -ne $rawSubFolder) {
        $sub = Get-ScrubbedString -string $rawSubFolder -invalidChars $invalidChars -maxLength $maxLengthSubFolder -trimEnds -singleReplace
        if ($sub.Length -gt 0) {
            $subFolder = $sub
        }
    }

    $ObjectGuid = [System.Guid]::empty
    $isGuid = [System.Guid]::TryParse($name, [System.Management.Automation.PSReference]$ObjectGuid)
    $fileName = $name
    if ($isGuid) {
        # try to avoid GUID file names
        $fileNameTemp = $displayName
        $fileNameTemp = Get-ScrubbedString -string $fileNameTemp -invalidChars $invalidChars -replaceWith "" -replaceSpaces -replaceSpacesWith "-" -maxLength $maxLengthFileName -trimEnds -toLower -singleReplace
        if ($fileNameTemp.Length -gt 0) {
            $fileName = $fileNameTemp
        }
    }
    else {
        $fileName = Get-ScrubbedString -string $name -invalidChars $invalidChars -replaceWith "" -replaceSpaces -replaceSpacesWith "-" -maxLength $maxLengthFileName -trimEnds -toLower -singleReplace
    }

    $fullPath = if ($null -ne $rawSubFolder) {
        "$folder/$subFolder/$($fileName)$($fileSuffix).$fileExtension"
    }
    else {
        "$folder/$($fileName)$($fileSuffix).$fileExtension"
    }

    return $fullPath
}