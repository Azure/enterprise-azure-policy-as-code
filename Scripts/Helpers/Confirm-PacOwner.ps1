function Confirm-PacOwner {
    [CmdletBinding()]
    param (
        $ThisPacOwnerId,
        $Metadata,
        $ManagedByCounters
    )

    if ($null -eq $Metadata) {
        $ManagedByCounters.unknown += 1
        return "unknownOwner"
    }
    elseif ($null -eq $Metadata.pacOwnerId) {
        $ManagedByCounters.unknown += 1
        return "unknownOwner"
    }
    elseif ($ThisPacOwnerId -eq $Metadata.pacOwnerId) {
        $ManagedByCounters.thisPaC += 1
        return "thisPaC"
    }
    else {
        $ManagedByCounters.otherPaC += 1
        return "otherPaC"
    }
}
