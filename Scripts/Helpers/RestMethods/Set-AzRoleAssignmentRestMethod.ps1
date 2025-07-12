function Set-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        $RoleAssignment,
        [string] $ApiVersion
    )

    $properties = $RoleAssignment.properties
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
        properties = $RoleAssignment.properties
    }
    if ($body.properties.crossTenant -eq $true) {
        $body.properties["delegatedManagedIdentityResourceId"] = $roleassignment.assignmentId
    }


    Write-Information "Assignment '$($RoleAssignment.assignmentDisplayName)', principalId $($properties.principalId), role '$($RoleAssignment.roleDisplayName)' at $($scope)"

    # Invoke the REST API
    $bodyJson = ConvertTo-Json $body -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path $path -Method PUT -Payload $bodyJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        if ($statusCode -eq 409) {
            if ($response.content -match "ScopeLocked") {
                Write-Warning "Scope at $($RoleAssignment.scope) is locked, cannot update role assignment"
            }
            else {
                Write-Warning "Role assignment already exists (ignore): $($RoleAssignment.assignmentDisplayName)"
            }     
        }
        elseif ($statusCode -eq 403 -and $response.content -match "does not have authorization to perform action") {
            Write-Error "Error, Permissions Issue. Please review permissions for service principal at scope $($RoleAssignment.scope) -- $($response.content)"
        }
        elseif ($statusCode -eq 403 -and $response.content -match "has an authorization with ABAC condition that is not fulfilled to perform action") {
            Write-Error "Error, ABAC Permissions Issue. Please review permissions for service principal at scope $($RoleAssignment.scope) -- $($response.content)"
        }
        else {
            $content = $response.Content
            Write-Warning "Error, continue deployment: $($statusCode) -- $($content)"
        }
    }
}
