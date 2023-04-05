function Get-ScrubbedString {
    [CmdletBinding()]
    param (
        [string] $string,
        [char[]] $invalidChars = @(),
        [string] $replaceWith = "",
        [switch] $replaceSpaces,
        [string] $replaceSpacesWith = "",
        [int] $maxLength = 0,
        [switch] $trimEnds,
        [switch] $toLower,
        [switch] $singleReplace
    )

    [string] $result = $string
    if ($trimEnds) {
        $result = $result.Trim()
    }
    if ($toLower) {
        $result = $result.ToLower()
    }
    if ($invalidChars.Count -gt 0) {
        $result = $result.Split($invalidChars) -join $replaceWith
        if ($singleReplace -and $replaceWith.Length -gt 0) {
            $previousResult = ""
            while ($previousResult -ne $result) {
                $previousResult = $result
                $result = $result -replace "$($replaceWith)$($replaceWith)", $replaceWith
            }
        }
    }
    if ($replaceSpaces) {
        if ($singleReplace) {
            $result = $result -replace "  ", " "
        }
        $result = $result.Replace(" ", $replaceSpacesWith)
        if ($singleReplace -and $replaceSpacesWith.Length -gt 0) {
            while ($previousResult -ne $result) {
                $previousResult = $result
                $result = $result -replace "$($replaceSpacesWith)$($replaceSpacesWith)", $replaceSpacesWith
            }
        }
    }
    if ($maxLength -gt 0 -and $result.Length -gt $maxLength) {
        $result = $result.Substring(0, $maxLength)
    }
    return $result
}
