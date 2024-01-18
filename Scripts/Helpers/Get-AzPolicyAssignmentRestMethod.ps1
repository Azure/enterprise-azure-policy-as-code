function Get-AzPolicyAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [string] $AssignmentID
    )

    # Invoke the REST API
    $response = Invoke-AzRestMethod -Path "$($AssignmentId)?api-version=2022-06-01" -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Get Policy Assignment error for '$policyAssignmentId' $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $response.Content | ConvertFrom-Json -Depth 100
}
