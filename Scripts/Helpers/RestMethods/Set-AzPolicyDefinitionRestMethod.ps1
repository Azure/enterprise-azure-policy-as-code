function Set-AzPolicyDefinitionRestMethod {
    [CmdletBinding()]
    param (
        $DefinitionObj,
        $ApiVersion
    )

    # Write log info
    $displayName = $DefinitionObj.displayName
    Write-Information $displayName

    # Build the REST API body
    $properties = @{
        displayName = $DefinitionObj.displayName
        description = $DefinitionObj.description
        metadata    = $DefinitionObj.metadata
        # version     = $DefinitionObj.version
        mode        = $DefinitionObj.mode
        parameters  = $DefinitionObj.parameters
        policyRule  = $DefinitionObj.policyRule
    }
    # Remove-NullFields $properties - issue 619
    $definition = @{
        properties = $properties
    }

    # Invoke the REST API
    $definitionJson = ConvertTo-Json $definition -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($DefinitionObj.id)?api-version=$ApiVersion" -Method PUT -Payload $definitionJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Definition error $($statusCode) -- $($DefinitionObj.displayName) --$($content)" -ErrorAction Stop
    }
}
