function Set-AzRoleAssignmentRestMethod {
    [CmdletBinding()]
    param (
        $Scope,
        $ObjectType,
        $ObjectId,
        $RoleDefinitionId,
        $AssignmentDisplayName,
        $RoleDisplayName,
        [switch] $IgnoreDuplicateError
    )

    # Write log info
    Write-Information "Assignment '$AssignmentDisplayName', principalId $ObjectId, role $RoleDisplayName($roleDefinitionId) at $scope"

    # Build the Path
    $guid = New-Guid
    $path = "$scope/providers/Microsoft.Authorization/roleAssignments/$($guid.ToString())?api-version=2022-04-01"

    # Build the REST API body
    $body = @{
        properties = @{
            roleDefinitionId = $RoleDefinitionId
            principalId      = $ObjectId
            principalType    = $ObjectType
        }
    }

    # Invoke the REST API
    $bodyJson = ConvertTo-Json $body -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path $path -Method PUT -Payload $bodyJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        if ($IgnoreDuplicateError -and $statusCode -eq 409) {
            $errorBody = $content | ConvertFrom-Json -Depth 100
            Write-Information $errorBody.error.message
        }
        else {
            Write-Error "Role Assignment error $($statusCode) -- $($content)" -ErrorAction Stop
        }
    }
}
