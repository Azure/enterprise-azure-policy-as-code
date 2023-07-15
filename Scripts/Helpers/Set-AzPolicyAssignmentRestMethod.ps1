function Set-AzPolicyAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $AssignmentObj,
        [string] $CurrentDisplayName
    )

    # Write log info
    $displayName = $AssignmentObj.displayName
    if ($displayName -ne $CurrentDisplayName) {
        Write-Information $displayName
    }
    Write-Information "    $($AssignmentObj.id)"

    # Fix parameters to the weird way assignments uses JSON
    $parametersTemp = Get-DeepClone $AssignmentObj.parameters -AsHashTable
    $parameters = @{}
    foreach ($parameterName in $parametersTemp.Keys) {
        $value = $parametersTemp.$parameterName
        $parameters.$parameterName = @{
            value = $value
        }
    }

    # Build the REST API body
    $assignment = @{
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
        $assignment.location = $AssignmentObj.managedIdentityLocation
    }
    if ($parameters.psbase.Count -gt 0) {
        $assignment.properties.parameters = $parameters
    }
    if ($AssignmentObj.nonComplianceMessages) {
        $assignment.properties.nonComplianceMessages = $AssignmentObj.nonComplianceMessages
    }
    if ($AssignmentObj.overrides) {
        $assignment.properties.overrides = $AssignmentObj.overrides
    }
    if ($AssignmentObj.resourceSelectors) {
        $assignment.properties.resourceSelectors = $AssignmentObj.resourceSelectors
    }

    # Invoke the REST API
    $assignmentJson = ConvertTo-Json $assignment -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($AssignmentObj.id)?api-version=2022-06-01" -Method PUT -Payload $assignmentJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -ne 201) {
        $content = $response.Content
        Write-Information "assignment: $assignmentJson"
        Write-Error "Assignment error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $displayName
}
