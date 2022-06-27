#Requires -PSEdition Core

function Confirm-AssignmentParametersMatch {
    [CmdletBinding()]
    param(
        [PSCustomObject] $existingParametersObj, 
        [hashtable] $definedParametersObj
    )
    $match = $true

    $existingParameters = ConvertTo-HashTable $existingParametersObj
    $definedParameters = $definedParametersObj.Clone()
    $addedParameters = $definedParameters.Clone()
    foreach ($existingParameterName in $existingParameters.Keys) {
        if ($definedParameters.ContainsKey($existingParameterName)) {
            # remove key from $addedParameters
            $addedParameters.Remove($existingParameterName)

            # analyze parameter
            if ($match) {
                $existing = $existingParameters.$existingParameterName.value
                $defined = $definedParameters.$existingParameterName
                $match = Confirm-ObjectValueEqualityDeep -existingObj $existing -definedObj $defined
            }
        }
        else {
            # parameter deleted
            $match = $false
            break
        }
    }
    if ($addedParameters.Count -gt 0) {
        $match = $false
    }

    return $match
}
