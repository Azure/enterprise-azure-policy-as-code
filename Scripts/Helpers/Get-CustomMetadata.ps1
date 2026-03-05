function Get-CustomMetadata {
    [CmdletBinding()]
    param (
        $Metadata,
        $Remove = $null
    )

    # Remove Azure system-generated metadata properties
    # These are automatically managed by Azure and should not be compared
    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
    
    $metadataTemp = ConvertTo-HashTable $Metadata
    foreach ($property in $systemManagedProperties) {
        if ($metadataTemp.Keys -contains $property) {
            $metadataTemp.Remove($property)
        }
    }
    
    if ($null -ne $Remove) {
        $splits = $Remove -split ","
        foreach ($item in  $splits) {
            $metadataTemp.Remove($item)
        }
    }

    return $metadataTemp
}
