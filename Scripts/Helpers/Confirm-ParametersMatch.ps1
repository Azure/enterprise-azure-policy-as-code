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
    $addedParameters = Get-HashtableShallowClone $definedParameters
    foreach ($existingParameterName in $existingParameters.Keys) {
        if ($definedParameters.Keys -contains $existingParameterName) {
            # Remove key from $addedParameters
            $addedParameters.Remove($existingParameterName)
            $existing = $existingParameters.$existingParameterName
            $defined = $definedParameters.$existingParameterName

            # Analyze parameter defaultValue
            $thisMatch = Confirm-ObjectValueEqualityDeep -existingObj $existing.defaultValue -definedObj $defined.defaultValue
            if (!$thisMatch) {
                $match = $false
                if ($null -eq $defined.defaultValue) {
                    $incompatible = $true
                    break
                }
            }

            # Analyze parameter allowedValues
            $thisMatch = Confirm-ObjectValueEqualityDeep -existingObj $existing.allowedValues -definedObj $defined.allowedValues
            if (!$thisMatch) {
                $match = $false
                if ($null -eq $defined.defaultValue) {
                    $incompatible = $true
                    break
                }
            }

            # Analyze type
            if ($existing.type -ne $defined.type) {
                $match = $false
                $incompatible = $true
                break
            }

            $existingMetadata = $existing.metadata
            $definedMetadata = $defined.metadata
            $thisMatch = Confirm-ObjectValueEqualityDeep -existingObj $existingMetadata -definedObj $definedMetadata
            if (!$thisMatch) {
                $match = $false
                if ($existingMetadata.strongType -ne $definedMetadata.strongType) {
                    $incompatible = $true
                    break
                }
            }
        }
        else {
            # parameter deleted, this is an incompatible change
            $match = $false
            $incompatible = $true
            break
        }
    }
    if ((-not $incompatible) -and ($addedParameters.Count -gt 0)) {
        $match = $false
        # If no defaultValue, added parameter makes it incompatible requiring a delete followed by a new.
        foreach ($addedParameterName in $addedParameters.Keys) {
            $added = $addedParameters.$addedParameterName
            if ($null -eq $added.defaultValue) {
                $incompatible = $true
                break
            }
        }
    }

    return $match, $incompatible
}
