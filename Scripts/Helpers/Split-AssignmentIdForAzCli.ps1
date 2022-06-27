
function Split-AssignmentIdForAzCli {
    [CmdletBinding()]
    param (
        [string] $id
    )

    $name = $id.Split('/')[-1]
    $scope = $id -ireplace [regex]::Escape("/providers/Microsoft.Authorization/policyAssignments/$name"), ""

    $splat = @{
        name  = $name
        scope = $scope
    }
    return $splat
}
