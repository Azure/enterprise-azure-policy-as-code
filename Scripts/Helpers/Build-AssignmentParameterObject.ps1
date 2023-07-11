function Build-AssignmentParameterObject {
    # Recursive Function
    param(
        [hashtable] $AssignmentParameters,
        [hashtable] $ParametersInPolicyDefinition
    )

    $parameterObject = @{}
    if ($ParametersInPolicyDefinition -and $AssignmentParameters -and $ParametersInPolicyDefinition.psbase.Count -gt 0 -and $AssignmentParameters.psbase.Count -gt 0) {
        foreach ($parameterName in $ParametersInPolicyDefinition.Keys) {
            if ($AssignmentParameters.Keys -contains $parameterName) {
                $AssignmentParameterValue = $AssignmentParameters.$parameterName
                $parameterDefinition = $ParametersInPolicyDefinition.$parameterName
                $defaultValue = $parameterDefinition.defaultValue
                if ($null -eq $defaultValue -or (-not (Confirm-ObjectValueEqualityDeep $defaultValue $AssignmentParameterValue))) {
                    # The parameter definition does not define a defaultValue or the assignment parameter value is not equal to the defined defaultValue
                    $parameterObject[$parameterName] = $AssignmentParameterValue
                }
            }
        }
    }
    return $parameterObject
}
