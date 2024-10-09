function Confirm-ValidPolicyResourceName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $Name
    )

    # Test is the Name has any characters from this string of characters "<>*%&:?.+/" in it or ends with a space
    if ($Name -match "[\<\>\*\%\&\:\?\+\/\\]" -or $Name.EndsWith(" ")) {
        return $false
    }
    else {
        return $true
    }
}
