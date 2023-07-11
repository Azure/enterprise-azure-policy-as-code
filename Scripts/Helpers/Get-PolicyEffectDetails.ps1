function Get-PolicyEffectDetails {
    [CmdletBinding()]
    param (
        $Policy
    )

    $EffectValue = $Policy.policyRule.then.effect
    $found, $parameterName = Get-ParameterNameFromValueString -ParamValue $EffectValue

    $result = @{}
    if ($found) {
        $Parameters = $Policy.parameters | ConvertTo-HashTable
        if ($Parameters.ContainsKey($parameterName)) {
            $parameter = $Parameters.$parameterName
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
            fixedValue    = $EffectValue
            defaultValue  = $EffectValue
            allowedValues = @( $EffectValue )
            type          = "FixedByPolicyDefinition"
        }
    }
    return $result
}
