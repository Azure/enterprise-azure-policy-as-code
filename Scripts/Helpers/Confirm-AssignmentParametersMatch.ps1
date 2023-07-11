function Confirm-AssignmentParametersMatch {
    [CmdletBinding()]
    param(
        $ExistingParametersObj,
        $DefinedParametersObj,
        [switch] $CompareTwoExistingParametersObj
    )

    $ExistingParameters = ConvertTo-HashTable $ExistingParametersObj
    $DefinedParameters = ConvertTo-HashTable $DefinedParametersObj
    $addedParameters = Get-HashtableShallowClone $DefinedParameters
    foreach ($ExistingParameterName in $ExistingParameters.Keys) {
        $found = $false
        foreach ($definedParameterName in $DefinedParameters.Keys) {
            if ($definedParameterName -eq $ExistingParameterName) {
                # remove key from $addedParameters
                $addedParameters.Remove($definedParameterName)

                # analyze parameter
                $Existing = $ExistingParameters.$ExistingParameterName.value
                $defined = $DefinedParameters.$definedParameterName
                if ($CompareTwoExistingParametersObj) {
                    $defined = $DefinedParameters.$definedParameterName.value
                }
                $match = Confirm-ObjectValueEqualityDeep $Existing $defined
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
