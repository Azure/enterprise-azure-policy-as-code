function Set-AzPolicyAssignmentRestMethod {
    [CmdletBinding()]
    param (
        $AssignmentObj,
        $ApiVersion
    )

    # Write log info
    $id = $AssignmentObj.id
    $displayName = $AssignmentObj.displayName
    Write-Information "$displayName - $id"

    # Fix parameters to the weird way assignments uses JSON
    $parametersTemp = Get-DeepCloneAsOrderedHashtable $AssignmentObj.parameters
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
        $assignment.location = $AssignmentObj.managedIdentityLocation | Select-Object -First 1
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
    $response = Invoke-AzRestMethod -Path "$($id)?api-version=$ApiVersion" -Method PUT -Payload $assignmentJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -ge 300 -or $statusCode -lt 200) {
        $content = $response.Content
        Write-Information "assignment: $assignmentJson"
        Write-Error "Definition error $($statusCode) -- $($AssignmentObj.displayName) --$($content)" -ErrorAction Stop
    }
}
