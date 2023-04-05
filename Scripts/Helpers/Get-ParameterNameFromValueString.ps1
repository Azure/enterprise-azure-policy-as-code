function Get-ParameterNameFromValueString {
    [CmdletBinding()]
    param (
        [string] $paramValue
    )

    if ($paramValue.StartsWith(("[parameters('")) -and $paramValue.EndsWith("')]")) {
        $value1 = $paramValue.Replace("[parameters('", "")
        $parameterName = $value1.Replace("')]", "")
        return $true, $parameterName
    }
    else {
        return $false, $null
    }
}
