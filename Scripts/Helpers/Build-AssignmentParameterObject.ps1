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
                $assignmentParameterValue = $AssignmentParameters.$parameterName
                $parameterDefinition = $ParametersInPolicyDefinition.$parameterName
                $defaultValue = $parameterDefinition.defaultValue
                if ($null -eq $defaultValue -or (-not (Confirm-ObjectValueEqualityDeep $defaultValue $assignmentParameterValue))) {
                    # The parameter definition does not define a defaultValue or the assignment parameter value is not equal to the defined defaultValue
                    $parameterObject[$parameterName] = $assignmentParameterValue
                }
            }
        }
    }
    return $parameterObject
}
