function Confirm-DeleteForStrategy {
    [CmdletBinding()]
    param (
        [string] $PacOwner,
        [string] $Strategy,
        [string] $Status,
        [string] $DeleteExpired,
        [string] $DeleteOrphaned,
        [string] $Removed,

        [Parameter(Mandatory = $false)]
        $KeepDfcSecurityAssignments = $false
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
        "managedByDfcSecurityPolicies" {
            !$KeepDfcSecurityAssignments -and $Strategy -eq "full"
            break
        }
        "managedByDfcDefenderPlans" {
            $false
            break
        }
    }
    return $shallDelete
}
