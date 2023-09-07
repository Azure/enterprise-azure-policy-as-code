function Confirm-PacOwner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ThisPacOwnerId,

        [Parameter(Mandatory = $false)]
        $Metadata = $null,

        [Parameter(Mandatory = $false)]
        $ManagedByCounters = $null
    )

    if ($null -eq $Metadata -or $null -eq $Metadata.pacOwnerId) {
        if ($null -ne $ManagedByCounters) {
            $ManagedByCounters.unknown += 1
        }
        return "unknownOwner"
    }
    elseif ($ThisPacOwnerId -eq $Metadata.pacOwnerId) {
        if ($null -ne $ManagedByCounters) {
            $ManagedByCounters.thisPaC += 1
        }
        return "thisPaC"
    }
    else {
        if ($null -ne $ManagedByCounters) {
            $ManagedByCounters.otherPaC += 1
        }
        return "otherPaC"
    }
}
