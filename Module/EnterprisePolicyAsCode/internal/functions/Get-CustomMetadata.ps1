function Get-CustomMetadata {
    [CmdletBinding()]
    param (
        $Metadata,
        $Remove = $null
    )

    # remove system generated metadata
    $metadataTemp = ConvertTo-HashTable $Metadata
    if ($metadataTemp.Keys -contains "createdBy") {
        $metadataTemp.Remove("createdBy")
    }
    if ($metadataTemp.Keys -contains "createdOn") {
        $metadataTemp.Remove("createdOn")
    }
    if ($metadataTemp.Keys -contains "updatedBy") {
        $metadataTemp.Remove("updatedBy")
    }
    if ($metadataTemp.Keys -contains "updatedOn") {
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
