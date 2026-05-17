function Get-AzPolicyAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [string] $AssignmentID,
        [string] $ApiVersion
    )

    # Invoke the REST API
    $response = Invoke-AzRestMethod -Path "$($AssignmentId)?api-version=$ApiVersion" -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Get Policy Assignment error for '$AssignmentId' $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $response.Content | ConvertFrom-Json -Depth 100
}
