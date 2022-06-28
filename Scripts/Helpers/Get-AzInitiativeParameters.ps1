#Requires -PSEdition Core

function Get-AzInitiativeParameters {
    [CmdletBinding()]
    param (
        [hashtable] $parametersIn = @{}, # empty hashtable means processing an initiative definitions instead of assignemnet(s)
        [hashtable] $definedParameters
    )

    [hashtable] $parametersOut = @{}
    foreach ($name in $definedParameters.Keys) {
        $definedParameter = $definedParameters.$name
        if ($parametersIn.ContainsKey($name)) {
            $parametersOut.Add($name, @{
                    paramValue   = $parametersIn[$name].value
                    type         = "SetInAssignment"
                    defaultValue = $definedParameter.defaultValue
                })
        }
        else {
            $parametersOut.Add($name, @{
                    paramValue   = $definedParameter.defaultValue
                    type         = "InitiativeDefaultValue"
                    defaultValue = $definedParameter.defaultValue
                })
        }
    }
    return $parametersOut
}
