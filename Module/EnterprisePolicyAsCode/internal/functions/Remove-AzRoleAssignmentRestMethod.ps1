function Remove-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [string] $RoleAssignmentId,
        [string] $TenantId,
        [string] $ApiVersion,
        [string] $AssignmentId
    )

    # $body = @{
    #     properties = @{
    #         delegatedManagedIdentityResourceId = $AssignmentId
    #     }
    # }
    # $bodyJson = ConvertTo-Json $body -Depth 100 -Compress

    # Call REST API to delete role assignment
    if (!$TenantId) {
        $checkExists = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion" -Method GET -ErrorAction SilentlyContinue
        if ($checkExists.StatusCode -eq 200 -or $checkCrossExists.StatusCode -eq 200) {
        $response = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion" -Method Delete
        }
        else {
            Write-ModernStatus -Message "Role assignment already deleted (ignore)" -Status "warning" -Indent 6
            Write-Information ""
            return
        }
    }
    else {
        # When cross tenant deleting, if the role is not there anymore, the error returned is a 403 or 404. To avoid failing the deployment in this case, first check if the role assignment exists.
        $checkExists = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion" -Method GET -ErrorAction SilentlyContinue
        $checkCrossExists = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion&tenantId=$($TenantId)" -Method GET -ErrorAction SilentlyContinue
        if ($checkExists.StatusCode -eq 200 -or $checkCrossExists.StatusCode -eq 200) {
            $response = Invoke-AzRestMethod -Path "$($RoleAssignmentId)?api-version=$ApiVersion&tenantId=$($TenantId)" -Method Delete #-Payload $bodyJson
        }
        else {
            Write-ModernStatus -Message "Role assignment already deleted (ignore)" -Status "warning" -Indent 6
            Write-Information ""
            return
        }
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
    else {
        Write-ModernStatus -Message "Removed role successfully" -Status "success" -Indent 6
        Write-Information ""
    }
}