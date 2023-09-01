function Set-AzPolicySetDefinitionRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $DefinitionObj
    )

    # Write log info
    $displayName = $DefinitionObj.displayName
    $id = $DefinitionObj.id
    Write-Information "$displayName($id)"

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
    $definition = @{
        properties = $properties
    }

    # Invoke the REST API
    $payload = ConvertTo-Json $definition -Depth 100 -Compress
    $path = "$($DefinitionObj.id)?api-version=2021-06-01"
    $objectName = "Policy Set (Initiative) Definition"
    $null = Invoke-AzRestMethodWrapper -ObjectName $objectName -Path $path -Method PUT -Payload $payload
}
