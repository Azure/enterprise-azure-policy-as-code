function Set-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        $RoleAssignment,
        $PacEnvironment,
        [Parameter(Mandatory = $false)]
        [bool] $skipDelegated = $false
    )

    $ApiVersion = $PacEnvironment.apiVersions.roleAssignments
    $path = $null
    $scope = $RoleAssignment.scope
    if ($null -ne $RoleAssignment.id) {
        # update existing role assignment
        $path = "$($RoleAssignment.id)?api-version=$ApiVersion"
    }
    else {
        # create new role assignment
        $guid = New-Guid
        $path = "$scope/providers/Microsoft.Authorization/roleAssignments/$($guid.ToString())?api-version=$ApiVersion"
    }
    $body = @{
        properties = @{} + $RoleAssignment.properties
    }

    if ($PacEnvironment.managedTenantId -and !$skipDelegated) {
        $body.properties["delegatedManagedIdentityResourceId"] = $roleassignment.assignmentId
    }

    # Retry at most once with the alternate delegated identity payload.
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        $bodyJson = ConvertTo-Json $body -Depth 100 -Compress
        $response = Invoke-AzRestMethod -Path $path -Method PUT -Payload $bodyJson

        if ($attempt -eq 0) {
            if ($response.StatusCode -eq 403 -and $response.Content -match "has an authorization with ABAC condition that is not fulfilled to perform action" -and !$skipDelegated -and !$body.properties.ContainsKey("delegatedManagedIdentityResourceId")) {
                $body.properties["delegatedManagedIdentityResourceId"] = $RoleAssignment.assignmentId
                continue
            }
            elseif ($PacEnvironment.managedTenantId -and $response.StatusCode -eq 400 -and $response.Content -match "delegatedManagedIdentityResourceId in the request is set to" -and $body.properties.ContainsKey("delegatedManagedIdentityResourceId")) {
                $body.properties.Remove("delegatedManagedIdentityResourceId")
                continue
            }
        }
        break
    }

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        if ($statusCode -eq 409) {
            if ($response.content -match "ScopeLocked") {
                Write-ModernStatus -Message "Scope at $($RoleAssignment.scope) is locked, cannot update role assignment" -Status "warning" -Indent 2
                Write-Information ""
            }
            else {
                Write-ModernStatus -Message "Role assignment already exists (ignore): $($RoleAssignment.assignmentDisplayName)" -Status "warning" -Indent 6
                Write-Information ""
            }
        }
        elseif ($statusCode -eq 403 -and $response.content -match "does not have authorization to perform action") {
            Write-ModernStatus -Message "Error, Permissions Issue. Please review permissions for service principal at scope $($RoleAssignment.scope) -- $($response.content)" -Status "error" -Indent 2
            Write-Information ""
        }
        elseif ($statusCode -eq 403 -and $response.content -match "has an authorization with ABAC condition that is not fulfilled to perform action") {
            Write-ModernStatus -Message "Error, ABAC Permissions Issue. Please review permissions for service principal at scope $($RoleAssignment.scope) -- $($response.content)" -Status "error" -Indent 2
            Write-Information ""
        }
        else {
            $content = $response.Content
            Write-ModernStatus -Message "Error, continue deployment: $($statusCode) -- $($content)" -Status "error" -Indent 2
            Write-Information ""
        }
    }
    else {
        Write-ModernStatus -Message "Created role assignment for principal successfully!" -Status "success" -Indent 6
        Write-Information ""
    }
}