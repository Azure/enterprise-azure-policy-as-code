function Confirm-ParametersDefinitionMatch {
    [CmdletBinding()]
    param(
        [PSCustomObject] $ExistingParametersObj,
        [PSCustomObject] $DefinedParametersObj
    )
    $match = $true
    $incompatible = $false

    $existingParameters = Get-ClonedObject $ExistingParametersObj -AsHashTable
    $definedParameters = Get-ClonedObject $DefinedParametersObj -AsHashTable
    $addedParameters = Get-ClonedObject $definedParameters -AsHashTable
    foreach ($existingParameterName in $existingParameters.Keys) {
        # ignore paramer name case
        $definedParameterNameArray = $definedParameters.Keys -eq $existingParameterName
        if ($definedParameterNameArray.Count -gt 0) {
            # found a matching parameter name (case insensitive)
            $definedParameterName = $definedParameterNameArray[0]
            $addedParameters.Remove($definedParameterName)
            $existing = $existingParameters.$existingParameterName
            $defined = $definedParameters.$definedParameterName
            $thisMatch = Confirm-ObjectValueEqualityDeep $existing $defined
            if ($thisMatch) {
                continue
            }
            $match = $false

            # analyze parameter type
            if ($existing.type -ne $defined.type) {
                $match = $false
                $incompatible = $true
                break
            }

            # analyze parameter metadata strongType
            $existingMetadata = $existing.metadata
            $definedMetadata = $defined.metadata
            if ($existingMetadata.strongType -ne $definedMetadata.strongType) {
                $incompatible = $true
                break
            }

            # analyze parameter allowedValues
            $thisMatch = Confirm-ObjectValueEqualityDeep $existing.allowedValues $defined.allowedValues
            if (!$thisMatch) {
                $incompatible = $true
                break
            }
        }
        else {
            # parameter deleted, this is an incompatible change
            $match = $false
            $incompatible = $true
            break
        }
    }
    
    if ($match -and !$incompatible -and ($addedParameters.psbase.Count -gt 0)) {
        $match = $false
        # added parameter without defaultValue is and incompatible change
        foreach ($addedParameterName in $addedParameters.Keys) {
            $added = $addedParameters.$addedParameterName
            if ($null -eq $added.defaultValue) {
                $incompatible = $true
                break
            }
        }
    }

    if (!$match) {
        Write-Verbose "Parameters definition mismatch detected, incompatible: $incompatible"
    }

    return $match, $incompatible
}
