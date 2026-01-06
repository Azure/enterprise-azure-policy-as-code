function Confirm-MetadataMatches {
    [CmdletBinding()]
    param(
        $ExistingMetadataObj,
        $DefinedMetadataObj,
        [bool] $GenerateDiff = $false
    )

    $match = $false
    $changePacOwnerId = $false
    $diff = @()
    
    if ($null -eq $ExistingMetadataObj) {
        if ($GenerateDiff) {
            return @{
                match            = $false
                changePacOwnerId = $true
                diff             = $diff
            }
        }
        return $false, $true
    }
    $existingMetadata =  Get-DeepCloneAsOrderedHashtable $ExistingMetadataObj
    $definedMetadata = Get-DeepCloneAsOrderedHashtable $DefinedMetadataObj

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
    if ($existingMetadata.ContainsKey("lastSyncedToArgOn")) {
        $existingMetadata.Remove("lastSyncedToArgOn")
    }

    $existingPacOwnerId = $existingMetadata.pacOwnerId
    $definedPacOwnerId = $definedMetadata.pacOwnerId
    if ($existingPacOwnerId -ne $definedPacOwnerId) {
        # Only show verbose output if not using detailed diff mode
        if (-not (Get-Variable -Name EPAC_DiffGranularity -Scope Global -ValueOnly -ErrorAction SilentlyContinue) -or 
            (Get-Variable -Name EPAC_DiffGranularity -Scope Global -ValueOnly -ErrorAction SilentlyContinue) -eq "standard") {
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

    if (!$match -and $GenerateDiff) {
        # Generate detailed diff for metadata changes
        foreach ($key in $definedMetadata.Keys) {
            if ($existingMetadata.ContainsKey($key)) {
                if (!(Confirm-ObjectValueEqualityDeep $existingMetadata.$key $definedMetadata.$key)) {
                    $diff += New-DiffEntry -Operation "replace" -Path "/metadata/$key" `
                        -Before $existingMetadata.$key -After $definedMetadata.$key -Classification "metadata"
                }
            }
            else {
                $diff += New-DiffEntry -Operation "add" -Path "/metadata/$key" `
                    -After $definedMetadata.$key -Classification "metadata"
            }
        }
        foreach ($key in $existingMetadata.Keys) {
            if (!$definedMetadata.ContainsKey($key)) {
                $diff += New-DiffEntry -Operation "remove" -Path "/metadata/$key" `
                    -Before $existingMetadata.$key -Classification "metadata"
            }
        }
    }
    
    if ($GenerateDiff) {
        return @{
            match            = $match
            changePacOwnerId = $changePacOwnerId
            diff             = $diff
        }
    }
    return $match, $changePacOwnerId
}
