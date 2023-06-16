function Build-AssignmentParameterObject {
    # Recursive Function
    param(
        [hashtable] $assignmentParameters,
        [hashtable] $parametersInPolicyDefinition
    )

    $parameterObject = @{}
    if ($parametersInPolicyDefinition -and $assignmentParameters -and $parametersInPolicyDefinition.psbase.Count -gt 0 -and $assignmentParameters.psbase.Count -gt 0) {
        foreach ($parameterName in $parametersInPolicyDefinition.Keys) {
            if ($assignmentParameters.Keys -contains $parameterName) {
                $assignmentParameterValue = $assignmentParameters.$parameterName
                $parameterDefinition = $parametersInPolicyDefinition.$parameterName
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