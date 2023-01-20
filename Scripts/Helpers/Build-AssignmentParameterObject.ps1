#Requires -PSEdition Core

function Build-AssignmentParameterObject {
    # Recursive Function
    param(
        [hashtable] $assignmentParameters,
        [hashtable] $parametersInPolicyDefinition
    )

    $parameterObject = @{}
    if ($parametersInPolicyDefinition -and $assignmentParameters -and $parametersInPolicyDefinition.Count -gt 0 -and $assignmentParameters.Count -gt 0) {
        foreach ($parameterName in $parametersInPolicyDefinition.Keys) {
            if ($assignmentParameters.ContainsKey($parameterName)) {
                $assignmentParameterValue = $assignmentParameters.$parameterName
                $parameterObject[$parameterName] = $assignmentParameterValue
            }
        }
    }
    $parameterObject
}