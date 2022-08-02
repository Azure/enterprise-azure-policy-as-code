#Requires -PSEdition Core

function Confirm-MetadataMatches {
    [CmdletBinding()]
    param(
        $existingMetadataObj,
        $definedMetadataObj
    )

    $match = $false

    if ($null -eq $existingMetadataObj -or $existingMetadataObj -eq @{}) {
        if ($null -eq $definedMetadataObj -or $definedMetadataObj -eq @{}) {
            $match = $true
        }
    }
    else {
        # remove system generated metadata from consideration
        $existingMetadata = @{}
        if ($existingMetadataObj -isnot [hashtable]) {
            $existingMetadata = ConvertTo-HashTable $existingMetadataObj
        }
        else {
            $existingMetadata = Get-DeepClone -InputObject $existingMetadataObj
        }
        if ($existingMetadata.ContainsKey("createdBy")) {
            $existingMetadata.Remove("createdBy")
        }
        if ($existingMetadata.ContainsKey("createdOn")) {
            $existingMetadata.Remove("createdOn")
        }
        if ($existingMetadata.ContainsKey("updatedBy")) {
            $existingMetadata.Remove("updatedBy")
        }
        if ($existingMetadata.ContainsKey("updatedOn")) {
            $existingMetadata.Remove("updatedOn")
        }
        if ($null -eq $definedMetadataObj -or $definedMetadataObj -eq @{}) {
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
