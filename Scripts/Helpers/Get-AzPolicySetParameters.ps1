function Get-AzPolicySetParameters {
    [CmdletBinding()]
    param (
        [hashtable] $ParametersIn = @{}, # empty hashtable means processing a Policy Set instead of Assignment(s)
        [hashtable] $DefinedParameters
    )

    [hashtable] $ParametersOut = @{}
    foreach ($Name in $DefinedParameters.Keys) {
        $definedParameter = $DefinedParameters.$Name
        if ($ParametersIn.ContainsKey($Name)) {
            $null = $ParametersOut.Add($Name, @{
                    paramValue   = $ParametersIn[$Name].value
                    type         = "SetInAssignment"
                    defaultValue = $definedParameter.defaultValue
                })
        }
        else {
            $null = $ParametersOut.Add($Name, @{
                    paramValue   = $definedParameter.defaultValue
                    type         = "PolicySet DefaultValue"
                    defaultValue = $definedParameter.defaultValue
                })
        }
    }
    return $ParametersOut
}
