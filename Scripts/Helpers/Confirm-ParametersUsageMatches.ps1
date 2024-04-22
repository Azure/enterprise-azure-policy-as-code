function Confirm-ParametersUsageMatches {
    [CmdletBinding()]
    param(
        $ExistingParametersObj,
        $DefinedParametersObj,
        [switch] $CompareValueEntryForExistingParametersObj,
        [switch] $CompareValueEntryForDefinedParametersObj
    )

    $existingParameters = ConvertTo-HashTable $ExistingParametersObj
    $definedParameters = ConvertTo-HashTable $DefinedParametersObj

    $allKeys = $existingParameters.Keys + $definedParameters.Keys
    if ($existingParameters.psbase.Count -ne $definedParameters.psbase.Count) {
        # parameter count changed
        return $false
    }
    $uniqueKeys = $allKeys | Sort-Object -Unique
    if ($existingParameters.psbase.Count -ne $uniqueKeys.Count -or $definedParameters.psbase.Count -ne $uniqueKeys.Count) {
        # parameter names do not match
        return $false
    }
    foreach ($existingParameterName in $existingParameters.Keys) {
        $definedParameterNameArray = $definedParameters.Keys -eq $existingParameterName
        if ($definedParameterNameArray.Count -eq 0) {
            # No matching parameter name found (case insensitive)
            return $false
        }
        $definedParameterName = $definedParameterNameArray[0]
        $existingParameter = $existingParameters.$existingParameterName
        $definedParameter = $definedParameters.$definedParameterName

        $existingParameterValue = $existingParameter
        if ($null -ne $existingParameterValue.value) {
            $existingParameterValue = $existingParameter.value
        }
        $definedParameterValue = $definedParameter
        if ($null -ne $definedParameterValue.value) {
            $definedParameterValue = $definedParameter.value
        }

        if (!(Confirm-ObjectValueEqualityDeep $existingParameterValue $definedParameterValue)) {
            return $false
        }
    }
    return $true
}
