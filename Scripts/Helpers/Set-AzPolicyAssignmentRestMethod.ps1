function Set-AzPolicyAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $AssignmentObj,
        [string] $CurrentDisplayName
    )

    # Write log info
    $DisplayName = $AssignmentObj.displayName
    if ($DisplayName -ne $CurrentDisplayName) {
        Write-Information $DisplayName
    }
    Write-Information "    $($AssignmentObj.id)"

    # Fix parameters to the weird way assignments uses JSON
    $ParametersTemp = Get-DeepClone $AssignmentObj.parameters -AsHashtable
    $Parameters = @{}
    foreach ($parameterName in $ParametersTemp.Keys) {
        $value = $ParametersTemp.$parameterName
        $Parameters.$parameterName = @{
            value = $value
        }
    }

    # Build the REST API body
    $Assignment = @{
        identity   = $AssignmentObj.identity
        properties = @{
            policyDefinitionId = $AssignmentObj.policyDefinitionId
            displayName        = $AssignmentObj.displayName
            description        = $AssignmentObj.description
            metadata           = $AssignmentObj.metadata
            enforcementMode    = $AssignmentObj.enforcementMode
            notScopes          = $AssignmentObj.notScopes
        }
    }
    if ($AssignmentObj.identityRequired) {
        $Assignment.location = $AssignmentObj.managedIdentityLocation
    }
    if ($Parameters.psbase.Count -gt 0) {
        $Assignment.properties.parameters = $Parameters
    }
    if ($AssignmentObj.nonComplianceMessages) {
        $Assignment.properties.nonComplianceMessages = $AssignmentObj.nonComplianceMessages
    }
    if ($AssignmentObj.overrides) {
        $Assignment.properties.overrides = $AssignmentObj.overrides
    }
    if ($AssignmentObj.resourceSelectors) {
        $Assignment.properties.resourceSelectors = $AssignmentObj.resourceSelectors
    }

    # Invoke the REST API
    $AssignmentJson = ConvertTo-Json $Assignment -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($AssignmentObj.id)?api-version=2022-06-01" -Method PUT -Payload $AssignmentJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -ne 201) {
        $content = $response.Content
        Write-Information "assignment: $AssignmentJson"
        Write-Error "Assignment error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $DisplayName
}
