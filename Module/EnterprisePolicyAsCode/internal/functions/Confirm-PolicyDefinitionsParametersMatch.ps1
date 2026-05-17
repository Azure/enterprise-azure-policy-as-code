function Confirm-PolicyDefinitionsParametersMatch {
    [CmdletBinding()]
    param(
        $ExistingParametersObj,
        $DefinedParametersObj
    )

    if ($null -eq $ExistingParametersObj) {
        $ExistingParametersObj = @{}
    }
    if ($null -eq $DefinedParametersObj) {
        $DefinedParametersObj = @{}
    }
    $addedParameters = $DefinedParametersObj.Clone()
    foreach ($existingParameterName in $ExistingParametersObj.Keys) {
        $definedParameterNameArray = $DefinedParametersObj.Keys -eq $existingParameterName
        if ($definedParameterNameArray.Count -gt 0) {
            # remove key from $addedParameters
            $addedParameters.Remove($definedParameterName)

            # analyze parameter
            $existing = $ExistingParametersObj.$existingParameterName
            $defined = $DefinedParametersObj.$definedParameterName
            $match = Confirm-ObjectValueEqualityDeep $existing $defined
            if (!$match) {
                return $false
            }
        }
        else {
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
