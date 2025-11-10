function Remove-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [string] $RoleAssignmentId,
        [string] $TenantId,
        [string] $ApiVersion,
        [string] $AssignmentId
    )

    $body = @{
        properties = @{
            delegatedManagedIdentityResourceId = $AssignmentId
        }
    }
    $bodyJson = ConvertTo-Json $body -Depth 100 -Compress

    # Call REST API to delete role assignment
    if (!$TenantId) {
        $response = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion" -Method Delete
    }
    else {
        $response = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion&tenantId=$($TenantId)" -Method Delete -Payload $bodyJson
    }

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        if ($content.Contains("ScopeLocked", [StringComparison]::InvariantCultureIgnoreCase)) {
            Write-Warning "Ignoring scope locked error: $($statusCode) -- $($content)"
        }
        else {
            Write-Error "Role assignment deletion failed with error $($statusCode) -- $($content)" -ErrorAction Stop
        }
    }
}