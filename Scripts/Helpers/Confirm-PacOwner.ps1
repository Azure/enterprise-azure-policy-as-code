function Confirm-PacOwner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ThisPacOwnerId,

        [Parameter(Mandatory = $true)]
        $Metadata,

        [Parameter(Mandatory = $false)]
        $ManagedByCounters = [pscustomobject]@{
            thisPaC  = 0
            otherPaC = 0
            unknown  = 0
        }
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
