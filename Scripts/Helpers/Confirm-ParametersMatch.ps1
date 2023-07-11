function Confirm-ParametersMatch {
    [CmdletBinding()]
    param(
        [PSCustomObject] $ExistingParametersObj,
        [PSCustomObject] $DefinedParametersObj
    )
    $match = $true
    $incompatible = $false

    $ExistingParameters = ConvertTo-HashTable $ExistingParametersObj
    $DefinedParameters = ConvertTo-HashTable $DefinedParametersObj
    $addedParameters = Get-HashtableShallowClone $DefinedParameters
    foreach ($ExistingParameterName in $ExistingParameters.Keys) {
        if ($DefinedParameters.Keys -contains $ExistingParameterName) {
            # Remove key from $addedParameters
            $addedParameters.Remove($ExistingParameterName)
            $Existing = $ExistingParameters.$ExistingParameterName
            $defined = $DefinedParameters.$ExistingParameterName

            # Analyze parameter defaultValue
            $thisMatch = Confirm-ObjectValueEqualityDeep $Existing.defaultValue $defined.defaultValue
            if (!$thisMatch) {
                $match = $false
                if ($null -eq $defined.defaultValue) {
                    $incompatible = $true
                    break
                }
            }

            # Analyze parameter allowedValues
            $thisMatch = Confirm-ObjectValueEqualityDeep $Existing.allowedValues $defined.allowedValues
            if (!$thisMatch) {
                $match = $false
                if ($null -eq $defined.defaultValue) {
                    $incompatible = $true
                    break
                }
            }

            # Analyze type
            if ($Existing.type -ne $defined.type) {
                $match = $false
                $incompatible = $true
                break
            }

            $ExistingMetadata = $Existing.metadata
            $definedMetadata = $defined.metadata
            $thisMatch = Confirm-ObjectValueEqualityDeep $ExistingMetadata $definedMetadata
            if (!$thisMatch) {
                $match = $false
                if ($ExistingMetadata.strongType -ne $definedMetadata.strongType) {
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
