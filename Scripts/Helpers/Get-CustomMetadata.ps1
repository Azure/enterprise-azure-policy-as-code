function Get-CustomMetadata {
    [CmdletBinding()]
    param (
        $Metadata,
        $Remove = $null
    )

    # remove system generated metadata
    $MetadataTemp = ConvertTo-HashTable $Metadata
    if ($MetadataTemp.ContainsKey("createdBy")) {
        $MetadataTemp.Remove("createdBy")
    }
    if ($MetadataTemp.ContainsKey("createdOn")) {
        $MetadataTemp.Remove("createdOn")
    }
    if ($MetadataTemp.ContainsKey("updatedBy")) {
        $MetadataTemp.Remove("updatedBy")
    }
    if ($MetadataTemp.ContainsKey("updatedOn")) {
        $MetadataTemp.Remove("updatedOn")
    }
    if ($null -ne $Remove) {
        $splits = $Remove -split ","
        foreach ($item in  $splits) {
            $MetadataTemp.Remove($item)
        }
    }

    return $MetadataTemp
}
