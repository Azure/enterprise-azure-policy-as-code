function Remove-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [string] $RoleAssignmentId
    )

    $response = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=2022-04-01" -Method Delete

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Role assignment deletion failed with error $($statusCode) -- $($content)" -ErrorAction Stop
    }
}
