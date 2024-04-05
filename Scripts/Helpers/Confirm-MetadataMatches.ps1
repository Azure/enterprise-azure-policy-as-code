function Confirm-MetadataMatches {
    [CmdletBinding()]
    param(
        $ExistingMetadataObj,
        $DefinedMetadataObj
    )

    $match = $false
    $changePacOwnerId = $false
    $existingMetadata = Get-ClonedObject $ExistingMetadataObj -AsHashTable
    $definedMetadata = Get-ClonedObject $DefinedMetadataObj -AsHashTable

    # remove system generated metadata from consideration
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

    $existingPacOwnerId = $existingMetadata.pacOwnerId
    $definedPacOwnerId = $definedMetadata.pacOwnerId
    if ($existingPacOwnerId -ne $definedPacOwnerId) {
        Write-Information "pacOwnerId has changed from '$existingPacOwnerId' to '$definedPacOwnerId'"
        $changePacOwnerId = $true
    }
    if ($definedMetadata.ContainsKey("pacOwnerId")) {
        $definedMetadata.Remove("pacOwnerId")
    }
    if ($existingMetadata.ContainsKey("pacOwnerId")) {
        $null = $existingMetadata.Remove("pacOwnerId")
    }
    if ($existingMetadata.psbase.Count -eq $definedMetadata.psbase.Count) {
        $match = Confirm-ObjectValueEqualityDeep $existingMetadata $definedMetadata
    }

    return $match, $changePacOwnerId
}
