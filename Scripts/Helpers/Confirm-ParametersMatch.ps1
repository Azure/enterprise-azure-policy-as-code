#Requires -PSEdition Core

function Confirm-ParametersMatch {
    [CmdletBinding()]
    param(
        [PSCustomObject] $existingParametersObj, 
        [PSCustomObject] $definedParametersObj
    )
    $match = $true
    $incompatible = $false

    $existingParameters = ConvertTo-HashTable $existingParametersObj
    $definedParameters = ConvertTo-HashTable $definedParametersObj
    $addedParameters = $definedParameters.Clone()
    foreach ($existingParameterName in $existingParameters.Keys) {
        if ($definedParameters.ContainsKey($existingParameterName)) {
            # remove key from $addedParameters
            $addedParameters.Remove($existingParameterName)

            # analyze parmeter
            if ($match) {
                $existing = $existingParameters.$existingParameterName
                $defined = $definedParameters.$existingParameterName
                $match = Confirm-ObjectValueEqualityDeep -existingObj $existing -definedObj $defined
            }
        }
        else {
            # parameter deleted, this is an incompatible change
            $match = $false
            $incompatible = $true
            break
        }
    }
    if (($incompatible -eq $false) -and ($addedParameters.Count -gt 0)) {
        $match = $false
        # If no defaultValue, added parameter makes it incompatible requiring a delete followed by a new. 
        foreach ($addedParameterName in $addedParameters.Keys) {
            $added = $addedParameters.$addedParameterName
            if ($null -eq $added.defaultvalue) {
                $incompatible = $true
                break
            }
        }
    }

    $result = @{
        match        = $match
        incompatible = $incompatible
    }
    return $result
}
