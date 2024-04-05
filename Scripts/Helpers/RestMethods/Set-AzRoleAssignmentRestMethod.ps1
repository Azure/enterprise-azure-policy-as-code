function Set-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        $RoleAssignment,
        [string] $ApiVersion
    )

    $properties = $RoleAssignment.properties
    $path = $null
    if ($null -ne $RoleAssignment.id) {
        # update existing role assignment
        $path = "$($RoleAssignment.id)?api-version=$ApiVersion"
    }
    else {
        # create new role assignment
        $guid = New-Guid
        $scope = $RoleAssignment.scope
        $path = "$scope/providers/Microsoft.Authorization/roleAssignments/$($guid.ToString())?api-version=$ApiVersion"
    }
    $body = @{
        properties = $RoleAssignment.properties
    }
    Write-Information "Assignment '$($RoleAssignment.assignmentDisplayName)', principalId $($properties.principalId), role '$($RoleAssignment.roleDisplayName)' at $scope"

    # Invoke the REST API
    $bodyJson = ConvertTo-Json $body -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path $path -Method PUT -Payload $bodyJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        if ($statusCode -eq 409) {
            $errorBody = $content | ConvertFrom-Json -Depth 100
            Write-Information $errorBody.error.message
        }
        else {
            Write-Error "Role Assignment error $($statusCode) -- $($content)" -ErrorAction Stop
        }
    }
}
