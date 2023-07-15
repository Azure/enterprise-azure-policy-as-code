function Get-ParameterNameFromValueString {
    [CmdletBinding()]
    param (
        [string] $ParamValue
    )

    if ($ParamValue.StartsWith(("[parameters('")) -and $ParamValue.EndsWith("')]")) {
        $value1 = $ParamValue.Replace("[parameters('", "")
        $parameterName = $value1.Replace("')]", "")
        return $true, $parameterName
    }
    else {
        return $false, $null
    }
}
