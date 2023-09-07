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
    if ($existingParameters.psbase.Count -ne $uniqueKeys.Count) {
        # parameter names do not match
        return $false
    }
    foreach ($existingParameterName in $existingParameters.Keys) {
        $existingParameter = $existingParameters.$existingParameterName
        $definedParameter = $definedParameters.$existingParameterName
        if ($null -eq $existingParameter) {
            # maybe case of key does not match, find key for existingParameters without considering case
            $key1 = $existingParameters.Keys | Where-Object { $_.ToLower() -eq $existingParameterName.ToLower() }
            if ($null -ne $key1) {
                Write-Debug "key '$existingParameterName' exists with a different case '$key1' in Object1 '$($existingParameters | ConvertTo-Json -Depth 100 -Compress)'"
                $existingParameter = $existingParameters.$key1
            }
            else {
                # this is a coding error
                Write-Error "Code bug: key '$existingParameterName' does not exist in existingParameters '$($existingParameters | ConvertTo-Json -Depth 100 -Compress)'" -ErrorAction Stop
            }
        }
        if ($null -eq $definedParameter) {
            # maybe case of key does not match, find key for definedParameters without considering case
            $key2 = $definedParameters.Keys | Where-Object { $_.ToLower() -eq $existingParameterName.ToLower() }
            if ($null -ne $key2) {
                Write-Debug "key '$existingParameterName' exists with a different case '$key2' in Object2 '$($definedParameters | ConvertTo-Json -Depth 100 -Compress)'"
                $definedParameter = $definedParameters.$key2
            }
            else {
                # this is a coding error
                Write-Error "Code bug: key '$existingParameterName' does not exist in definedParameters '$($definedParameters | ConvertTo-Json -Depth 100 -Compress)'" -ErrorAction Stop
            }
        }

        $existingParameterValue = $existingParameter
        if ($CompareValueEntryForExistingParametersObj) {
            $existingParameterValue = $existingParameter.value
        }
        $definedParameterValue = $definedParameter
        if ($CompareValueEntryForDefinedParametersObj) {
            $definedParameterValue = $definedParameter.value
        }

        if (!(Confirm-ObjectValueEqualityDeep $existingParameterValue $definedParameterValue -HandleRandomOrderArray)) {
            return $false
        }
    }
    return $true
}
