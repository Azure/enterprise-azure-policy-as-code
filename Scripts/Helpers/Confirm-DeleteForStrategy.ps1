function Confirm-DeleteForStrategy {
    [CmdletBinding()]
    param (
        [string] $PacOwner,
        [string] $Strategy,
        [string] $Status,
        [string] $DeleteExpired,
        [string] $DeleteOrphaned,
        [string] $Removed
    )

    $shallDelete = switch ($PacOwner) {
        "thisPaC" {
            if (($DeleteExpired -eq $false -and $Status -eq "expired") -or ($DeleteOrphaned -eq $false -and $Status -eq "orphaned") -and $Removed -eq $false) {
                $false
                break
            }
            else {
                $true
                break
            }
        }
        "otherPaC" {
            $false
            break
        }
        "unknownOwner" {
            $Strategy -eq "full"
            break
        }
    }
    return $shallDelete
}
