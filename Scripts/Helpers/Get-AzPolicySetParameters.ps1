function Get-AzPolicySetParameters {
    [CmdletBinding()]
    param (
        [hashtable] $parametersIn = @{}, # empty hashtable means processing a Policy Set instead of Assignment(s)
        [hashtable] $definedParameters
    )

    [hashtable] $parametersOut = @{}
    foreach ($name in $definedParameters.Keys) {
        $definedParameter = $definedParameters.$name
        if ($parametersIn.ContainsKey($name)) {
            $null = $parametersOut.Add($name, @{
                    paramValue   = $parametersIn[$name].value
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
