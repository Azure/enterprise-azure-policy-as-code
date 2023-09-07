function Get-CustomMetadata {
    [CmdletBinding()]
    param (
        $Metadata,
        $Remove = $null
    )

    # remove system generated metadata
    $metadataTemp = ConvertTo-HashTable $Metadata
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
    if ($null -ne $Remove) {
        $splits = $Remove -split ","
        foreach ($item in  $splits) {
            $metadataTemp.Remove($item)
        }
    }

    return $metadataTemp
}
