function Confirm-ParametersDefinitionMatch {
    [CmdletBinding()]
    param(
        [PSCustomObject] $ExistingParametersObj,
        [PSCustomObject] $DefinedParametersObj
    )
    $match = $true
    $incompatible = $false

    $existingParameters = ConvertTo-HashTable $ExistingParametersObj
    $definedParameters = ConvertTo-HashTable $DefinedParametersObj
    $addedParameters = Get-HashtableShallowClone $definedParameters
    foreach ($existingParameterName in $existingParameters.Keys) {
        if ($definedParameters.Keys -contains $existingParameterName) {
            # Remove key from $addedParameters
            $addedParameters.Remove($existingParameterName)
            $existing = $existingParameters.$existingParameterName
            $defined = $definedParameters.$existingParameterName

            # Analyze parameter defaultValue
            $thisMatch = Confirm-ObjectValueEqualityDeep $existing.defaultValue $defined.defaultValue
            if (!$thisMatch) {
                $match = $false
                if ($null -eq $defined.defaultValue) {
                    $incompatible = $true
                    break
                }
            }

            # Analyze parameter allowedValues
            $thisMatch = Confirm-ObjectValueEqualityDeep $existing.allowedValues $defined.allowedValues -HandleRandomOrderArray
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
            $thisMatch = Confirm-ObjectValueEqualityDeep $existingMetadata $definedMetadata -HandleRandomOrderArray
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
    if ((-not $incompatible) -and ($addedParameters.psbase.Count -gt 0)) {
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
