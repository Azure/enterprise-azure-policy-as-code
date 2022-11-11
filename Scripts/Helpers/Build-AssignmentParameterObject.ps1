#Requires -PSEdition Core

function Build-AssignmentParameterObject {
    # Recursive Function
    param(
        [hashtable] $assignmentParameters,
        [hashtable] $parametersInPolicyDefinition,
        [switch] $parameterSuppressDefaultValues
    )

    $parameterObject = @{}
    if ($parametersInPolicyDefinition -and $assignmentParameters -and $parametersInPolicyDefinition.Count -gt 0 -and $assignmentParameters.Count -gt 0) {
        foreach ($parameterName in $parametersInPolicyDefinition.Keys) {
            if ($assignmentParameters.ContainsKey($parameterName)) {
                $assignmentParameterValue = $assignmentParameters.$parameterName
                if ($parameterSuppressDefaultValues) {
                    $parameterDefinition = $parametersInPolicyDefinition.$parameterName
                    $defaultValue = $parameterDefinition.defaultValue
                    $isSameAsDefaultValue = Confirm-ObjectValueEqualityDeep -existingObj $defaultValue -definedObj $assignmentParameterValue
                    if (!$isSameAsDefaultValue) {
                        $parameterObject[$parameterName] = $assignmentParameterValue
                    }
                }
                else {
                    $parameterObject[$parameterName] = $assignmentParameterValue
                }
            }
        }
    }
    $parameterObject
}