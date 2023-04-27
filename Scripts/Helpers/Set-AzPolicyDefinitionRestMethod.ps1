function Set-AzPolicyDefinitionRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $definitionObj
    )

    # Write log info
    $displayName = $definitionObj.displayName
    Write-Information $displayName

    # Build the REST API body
    $properties = @{
        displayName = $definitionObj.displayName
        description = $definitionObj.description
        metadata    = $definitionObj.metadata
        # version     = $definitionObj.version
        mode        = $definitionObj.mode
        parameters  = $definitionObj.parameters
        policyRule  = $definitionObj.policyRule
    }
    Remove-NullFields $properties
    $definition = @{
        properties = $properties
    }

    # Invoke the REST API
    $definitionJson = ConvertTo-Json $definition -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($definitionObj.id)?api-version=2021-06-01" -Method PUT -Payload $definitionJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Policy definition error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $displayName
}
