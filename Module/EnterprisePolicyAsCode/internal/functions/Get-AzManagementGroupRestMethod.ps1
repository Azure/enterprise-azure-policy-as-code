
function Get-AzManagementGroupRestMethod {
    [CmdletBinding()]
    param (
        [string] $ApiVersion = "2020-05-01",
        [switch] $Expand,
        [switch] $Recurse,
        [string] $GroupID
    )

    # Print a message to indicate that the function is being called
    Write-Debug "Get-AzManagementGroupRestMethod is being called"

    # Assemble the API path
    $path = "/providers/Microsoft.Management/managementGroups/$($GroupID)?api-version=$($ApiVersion)"
    if ($Recurse) { 
        $path += "&`$recurse=True"
    }
    if ($Expand) {
        $path += "&`$expand=children"
    }

    # Print the GroupID and API path for debugging
    Write-Debug "GroupID: $GroupID"
    Write-Debug "API Path: $path"

    # Invoke the REST API
    $response = Invoke-AzRestMethod -Path $path -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Get Management Group error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    # Convert the response content to a JSON object
    $jsonContent = $response.Content | ConvertFrom-Json -Depth 100

    # $jsonText = $jsonContent | ConvertTo-Json -Depth 100

    return $jsonContent
}



