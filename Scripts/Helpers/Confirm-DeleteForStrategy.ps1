function Confirm-DeleteForStrategy {
    [CmdletBinding()]
    param (
        [string] $pacOwner,
        [string] $strategy
    )

    $shallDelete = switch ($pacOwner) {
        "thisPaC" {
            $true
            break
        }
        "otherPaC" {
            $false
            break
        }
        "unknownOwner" {
            $strategy -eq "full"
            break
        }
    }
    return $shallDelete
}
