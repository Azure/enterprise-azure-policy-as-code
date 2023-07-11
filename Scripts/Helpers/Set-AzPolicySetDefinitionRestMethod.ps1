function Set-AzPolicySetDefinitionRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $DefinitionObj
    )

    # Write log info
    $DisplayName = $DefinitionObj.displayName
    Write-Information $DisplayName

    # Build the REST API body
    $properties = @{
        displayName            = $DefinitionObj.displayName
        description            = $DefinitionObj.description
        metadata               = $DefinitionObj.metadata
        # version                = $DefinitionObj.version
        parameters             = $DefinitionObj.parameters
        policyDefinitions      = $DefinitionObj.policyDefinitions
        policyDefinitionGroups = $DefinitionObj.policyDefinitionGroups
    }
    Remove-NullFields $properties
    $Definition = @{
        properties = $properties
    }

    # Invoke the REST API
    $DefinitionJson = ConvertTo-Json $Definition -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($DefinitionObj.id)?api-version=2021-06-01" -Method PUT -Payload $DefinitionJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "definition error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $DisplayName
}
