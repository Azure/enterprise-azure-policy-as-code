#Requires -PSEdition Core

function Confirm-MetadataMatches {
    [CmdletBinding()]
    param(
        [PSCustomObject] $existingMetadataObj, 
        [PSCustomObject] $definedMetadataObj
    )

    $match = $false

    if ($null -eq $existingMetadataObj) {
        Write-Error "Existing metadata object cannot be `$null; this is likely a programming error"
    }
    else {
        # remove system generated metadata from consideration
        [hashtable] $existingMetadata = ConvertTo-HashTable $existingMetadataObj
        $existingMetadata.Remove("createdBy")
        $existingMetadata.Remove("createdOn")
        $existingMetadata.Remove("updatedBy")
        $existingMetadata.Remove("updatedOn")
        if ($null -eq $definedMetadataObj) {
            if ($existingMetadata.Count -eq 0) {
                $match = $true
            }
        }
        else {
            [hashtable] $definedMetadata = ConvertTo-HashTable $definedMetadataObj
            if ($existingMetadata.Count -eq $definedMetadata.Count) {
                $match = Confirm-ObjectValueEqualityDeep -existingObj $existingMetadata -definedObj $definedMetadata
            }
        }
    }

    return $match
}
