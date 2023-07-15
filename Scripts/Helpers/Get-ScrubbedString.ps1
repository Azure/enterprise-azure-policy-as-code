function Get-ScrubbedString {
    [CmdletBinding()]
    param (
        [string] $String,
        [char[]] $InvalidChars = @(),
        [string] $ReplaceWith = "",
        [switch] $ReplaceSpaces,
        [string] $ReplaceSpacesWith = "",
        [int] $MaxLength = 0,
        [switch] $TrimEnds,
        [switch] $ToLower,
        [switch] $SingleReplace
    )

    [string] $result = $String
    if ($TrimEnds) {
        $result = $result.Trim()
    }
    if ($ToLower) {
        $result = $result.ToLower()
    }
    if ($InvalidChars.Count -gt 0) {
        $result = $result.Split($InvalidChars) -join $ReplaceWith
        if ($SingleReplace -and $ReplaceWith.Length -gt 0) {
            $previousResult = ""
            while ($previousResult -ne $result) {
                $previousResult = $result
                $result = $result -replace "$($ReplaceWith)$($ReplaceWith)", $ReplaceWith
            }
        }
    }
    if ($ReplaceSpaces) {
        if ($SingleReplace) {
            $result = $result -replace "  ", " "
        }
        $result = $result.Replace(" ", $ReplaceSpacesWith)
        if ($SingleReplace -and $ReplaceSpacesWith.Length -gt 0) {
            while ($previousResult -ne $result) {
                $previousResult = $result
                $result = $result -replace "$($ReplaceSpacesWith)$($ReplaceSpacesWith)", $ReplaceSpacesWith
            }
        }
    }
    if ($MaxLength -gt 0 -and $result.Length -gt $MaxLength) {
        $result = $result.Substring(0, $MaxLength)
    }
    return $result
}
