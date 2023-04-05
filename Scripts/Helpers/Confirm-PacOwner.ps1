function Confirm-PacOwner {
    [CmdletBinding()]
    param (
        $thisPacOwnerId,
        $metadata,
        $managedByCounters
    )

    if ($null -eq $metadata) {
        $managedByCounters.unknown += 1
        return "unknownOwner"
    }
    elseif ($null -eq $metadata.pacOwnerId) {
        $managedByCounters.unknown += 1
        return "unknownOwner"
    }
    elseif ($thisPacOwnerId -eq $metadata.pacOwnerId) {
        $managedByCounters.thisPaC += 1
        return "thisPaC"
    }
    else {
        $managedByCounters.otherPaC += 1
        return "otherPaC"
    }
}
