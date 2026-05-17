function Get-DefinitionsFullPath {
    [CmdletBinding()]
    param (
        $Folder,
        $RawSubFolder = $null,
        $FileSuffix = "",
        $Name,
        $DisplayName,
        $InvalidChars,
        $MaxLengthSubFolder,
        $MaxLengthFileName,
        $FileExtension
    )

    $subFolder = "Unknown"
    if ($null -ne $RawSubFolder) {
        $sub = Get-ScrubbedString -String $RawSubFolder -InvalidChars $InvalidChars -MaxLength $MaxLengthSubFolder -TrimEnds -SingleReplace
        if ($sub.Length -gt 0) {
            $subFolder = $sub
        }
    }

    $ObjectGuid = [System.Guid]::empty
    $isGuid = [System.Guid]::TryParse($Name, [System.Management.Automation.PSReference]$ObjectGuid)
    $fileName = $Name
    if ($isGuid) {
        # try to avoid GUID file names
        $fileNameTemp = $DisplayName
        $fileNameTemp = Get-ScrubbedString -String $fileNameTemp -InvalidChars $InvalidChars -ReplaceWith "" -ReplaceSpaces -ReplaceSpacesWith "-" -MaxLength $MaxLengthFileName -TrimEnds -ToLower -SingleReplace
        if ($fileNameTemp.Length -gt 0) {
            $fileName = $fileNameTemp
        }
    }
    else {
        $fileName = Get-ScrubbedString -String $Name -InvalidChars $InvalidChars -ReplaceWith "" -ReplaceSpaces -ReplaceSpacesWith "-" -MaxLength $MaxLengthFileName -TrimEnds -ToLower -SingleReplace
    }

    $fullPath = if ($null -ne $RawSubFolder) {
        "$Folder/$subFolder/$($fileName)$($FileSuffix).$FileExtension"
    }
    else {
        "$Folder/$($fileName)$($FileSuffix).$FileExtension"
    }

    return $fullPath
}
