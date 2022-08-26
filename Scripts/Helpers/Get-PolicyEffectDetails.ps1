#Requires -PSEdition Core

function Get-PolicyEffectDetails {
    [CmdletBinding()]
    param (
        $policy
    )

    $effectValue = $policy.policyRule.then.effect
    $found, $parameterName = Get-ParameterNameFromValueString -paramValue $effectValue

    $result = @{}
    if ($found) {
        $parameters = $policy.parameters | ConvertTo-HashTable
        if ($parameters.ContainsKey($parameterName)) {
            $parameter = $parameters.$parameterName
            $result = @{
                paramValue    = $parameter.defaultValue
                defaultvalue  = $parameter.defaultValue
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
            defaultvalue  = $effectValue
            allowedValues = @( $effectValue )
            type          = "FixedByPolicyDefinition"
        }
    }
    return $result
}
