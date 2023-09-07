function Set-AzPolicyDefinitionRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $DefinitionObj
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
    Remove-NullFields $properties
    $definition = @{
        properties = $properties
    }

    # Invoke the REST API
    $definitionJson = ConvertTo-Json $definition -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($DefinitionObj.id)?api-version=2021-06-01" -Method PUT -Payload $definitionJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Policy definition error $($statusCode) -- $($content)" -ErrorAction Stop
    }
}
