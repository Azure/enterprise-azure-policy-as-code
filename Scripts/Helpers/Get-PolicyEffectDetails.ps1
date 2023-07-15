function Get-PolicyEffectDetails {
    [CmdletBinding()]
    param (
        $Policy
    )

    $effectValue = $Policy.policyRule.then.effect
    $found, $parameterName = Get-ParameterNameFromValueString -ParamValue $effectValue

    $result = @{}
    if ($found) {
        $parameters = $Policy.parameters | ConvertTo-HashTable
        if ($parameters.ContainsKey($parameterName)) {
            $parameter = $parameters.$parameterName
            $result = @{
                paramValue    = $parameter.defaultValue
                defaultValue  = $parameter.defaultValue
                allowedValues = $parameter.allowedValues
                parameterName = $parameterName
                type          = "Policy DefaultValue"
            }
        }
    }
    else {
        # Fixed value
        $result = @{
            fixedValue    = $effectValue
            defaultValue  = $effectValue
            allowedValues = @( $effectValue )
            type          = "FixedByPolicyDefinition"
        }
    }
    return $result
}
