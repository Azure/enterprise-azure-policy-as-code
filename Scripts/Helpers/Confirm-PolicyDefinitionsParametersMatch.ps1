function Confirm-PolicyDefinitionsParametersMatch {
    [CmdletBinding()]
    param(
        $ExistingParametersObj,
        $DefinedParametersObj
    )

    $existingParameters = ConvertTo-HashTable $ExistingParametersObj
    $definedParameters = ConvertTo-HashTable $DefinedParametersObj
    $addedParameters = Get-HashtableShallowClone $definedParameters
    foreach ($existingParameterName in $existingParameters.Keys) {
        $found = $false
        foreach ($definedParameterName in $definedParameters.Keys) {
            if ($definedParameterName -eq $existingParameterName) {
                # remove key from $addedParameters
                $addedParameters.Remove($definedParameterName)

                # analyze parameter
                $existing = $existingParameters.$existingParameterName
                $defined = $definedParameters.$definedParameterName
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
