function Confirm-MetadataMatches {
    [CmdletBinding()]
    param(
        $ExistingMetadataObj,
        $DefinedMetadataObj,
        [switch] $SuppressPacOwnerIdMessage
    )

    $match = $false
    $changePacOwnerId = $false
    if ($null -eq $ExistingMetadataObj) {
        return $false, $true
    }
    $existingMetadata =  Get-DeepCloneAsOrderedHashtable $ExistingMetadataObj
    $definedMetadata = Get-DeepCloneAsOrderedHashtable $DefinedMetadataObj

    # Remove Azure system-generated metadata properties
    # These are automatically managed by Azure and should not be compared
    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
    
    foreach ($property in $systemManagedProperties) {
        if ($existingMetadata.ContainsKey($property)) {
            $existingMetadata.Remove($property)
        }
    }

    $existingPacOwnerId = $existingMetadata.pacOwnerId
    $definedPacOwnerId = $definedMetadata.pacOwnerId
    if ($existingPacOwnerId -ne $definedPacOwnerId) {
        if (-not $SuppressPacOwnerIdMessage) {
            Write-Information "pacOwnerId has changed from '$existingPacOwnerId' to '$definedPacOwnerId'"
        }
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

    if (!$match) {
        $null = $null
    }
    return $match, $changePacOwnerId
}
