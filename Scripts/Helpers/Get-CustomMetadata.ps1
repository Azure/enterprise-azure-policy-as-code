function Get-CustomMetadata {
    [CmdletBinding()]
    param (
        $metadata,
        $remove = $null
    )

    # remove system generated metadata
    $metadataTemp = ConvertTo-HashTable $metadata
    if ($metadataTemp.ContainsKey("createdBy")) {
        $metadataTemp.Remove("createdBy")
    }
    if ($metadataTemp.ContainsKey("createdOn")) {
        $metadataTemp.Remove("createdOn")
    }
    if ($metadataTemp.ContainsKey("updatedBy")) {
        $metadataTemp.Remove("updatedBy")
    }
    if ($metadataTemp.ContainsKey("updatedOn")) {
        $metadataTemp.Remove("updatedOn")
    }
    if ($null -ne $remove) {
        $splits = $remove -split ","
        foreach ($item in  $splits) {
            $metadataTemp.Remove($item)
        }
    }

    return $metadataTemp
}
