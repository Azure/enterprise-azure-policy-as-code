function Remove-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [string] $RoleAssignmentId,
        [string] $TenantId,
        [string] $ApiVersion
    )
    if (!$TenantId) {
        $response = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion" -Method Delete
    }
    else {
        $response = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion&tenantId=$($TenantId)" -Method Delete
    }

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Role assignment deletion failed with error $($statusCode) -- $($content)" -ErrorAction Stop
    }
}
