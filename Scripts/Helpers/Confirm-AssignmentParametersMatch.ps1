function Confirm-AssignmentParametersMatch {
    [CmdletBinding()]
    param(
        $existingParametersObj,
        $definedParametersObj,
        [switch] $compareTwoExistingParametersObj
    )

    $existingParameters = ConvertTo-HashTable $existingParametersObj
    $definedParameters = ConvertTo-HashTable $definedParametersObj
    $addedParameters = Get-HashtableShallowClone $definedParameters
    foreach ($existingParameterName in $existingParameters.Keys) {
        $found = $false
        foreach ($definedParameterName in $definedParameters.Keys) {
            if ($definedParameterName -eq $existingParameterName) {
                # remove key from $addedParameters
                $addedParameters.Remove($definedParameterName)

                # analyze parameter
                $existing = $existingParameters.$existingParameterName.value
                $defined = $definedParameters.$definedParameterName
                if ($compareTwoExistingParametersObj) {
                    $defined = $definedParameters.$definedParameterName.value
                }
                $match = Confirm-ObjectValueEqualityDeep $existing $defined
                if (!$match) {
                    return $false
                }
                $found = $true
                break
            }
        }
        if (!$found) {
            # parameter deleted
            return $false
        }
    }

    # if condition instead of just returning the bool value is for easier debugging
    if ( $addedParameters.psbase.Count -eq 0) {
        # full match
        return $true
    }
    else {
        # parameter added
        return $false
    }
}
