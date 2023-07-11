function Confirm-MetadataMatches {
    [CmdletBinding()]
    param(
        $ExistingMetadataObj,
        $DefinedMetadataObj
    )

    $match = $false
    $changePacOwnerId = $false
    $ExistingMetadata = @{}
    if ($null -ne $ExistingMetadataObj) {
        $ExistingMetadata = Get-DeepClone $ExistingMetadataObj -AsHashtable
    }
    $definedMetadata = @{}
    if ($null -ne $DefinedMetadataObj) {
        $definedMetadata = Get-DeepClone $DefinedMetadataObj -AsHashtable
    }

    # remove system generated metadata from consideration
    if ($ExistingMetadata.ContainsKey("createdBy")) {
        $ExistingMetadata.Remove("createdBy")
    }
    if ($ExistingMetadata.ContainsKey("createdOn")) {
        $ExistingMetadata.Remove("createdOn")
    }
    if ($ExistingMetadata.ContainsKey("updatedBy")) {
        $ExistingMetadata.Remove("updatedBy")
    }
    if ($ExistingMetadata.ContainsKey("updatedOn")) {
        $ExistingMetadata.Remove("updatedOn")
    }

    $ExistingPacOwnerId = $ExistingMetadata.pacOwnerId
    $definedPacOwnerId = $definedMetadata.pacOwnerId
    if ($ExistingPacOwnerId -ne $definedPacOwnerId) {
        $changePacOwnerId = $true
        if ($definedMetadata.ContainsKey("pacOwnerId")) {
            $definedMetadata.Remove("pacOwnerId")
        }
        if ($ExistingMetadata.ContainsKey("pacOwnerId")) {
            $null = $ExistingMetadata.Remove("pacOwnerId")
        }
    }
    if ($ExistingMetadata.psbase.Count -eq $definedMetadata.psbase.Count) {
        $match = Confirm-ObjectValueEqualityDeep $ExistingMetadata $definedMetadata
    }

    return $match, $changePacOwnerId
}
