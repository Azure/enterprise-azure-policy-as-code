function Confirm-DeleteForStrategy {
    [CmdletBinding()]
    param (
        [string] $PacOwner,
        [string] $Strategy,
        [Parameter(Mandatory = $false)]
        $KeepDfcSecurityAssignments = $false,
        [Parameter(Mandatory = $false)]
        $KeepDfcPlanAssignments = $false
    )

    $shallDelete = switch ($PacOwner) {
        "thisPaC" {
            $true
        }
        "otherPaC" {
            $false
        }
        "unknownOwner" {
            $Strategy -eq "full"
        }
        "managedByDfcSecurityPolicies" {
            !$KeepDfcSecurityAssignments -and $Strategy -eq "full"
        }
        "managedByDfcDefenderPlans" {
            !$KeepDfcPlanAssignments -and $Strategy -eq "full"
        }
    }
    return $shallDelete
}
