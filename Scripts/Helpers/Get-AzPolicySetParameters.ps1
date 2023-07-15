function Get-AzPolicySetParameters {
    [CmdletBinding()]
    param (
        [hashtable] $ParametersIn = @{}, # empty hashtable means processing a Policy Set instead of Assignment(s)
        [hashtable] $DefinedParameters
    )

    [hashtable] $parametersOut = @{}
    foreach ($name in $DefinedParameters.Keys) {
        $definedParameter = $DefinedParameters.$name
        if ($ParametersIn.ContainsKey($name)) {
            $null = $parametersOut.Add($name, @{
                    paramValue   = $ParametersIn[$name].value
                    type         = "SetInAssignment"
                    defaultValue = $definedParameter.defaultValue
                })
        }
        else {
            $null = $parametersOut.Add($name, @{
                    paramValue   = $definedParameter.defaultValue
                    type         = "PolicySet DefaultValue"
                    defaultValue = $definedParameter.defaultValue
                })
        }
    }
    return $parametersOut
}
