function Set-AzPolicyAssignmentRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $assignmentObj,
        [string] $currentDisplayName
    )

    # Write log info
    $displayName = $assignmentObj.displayName
    if ($displayName -ne $currentDisplayName) {
        Write-Information $displayName
    }
    Write-Information "    $($assignmentObj.id)"

    # Fix parameters to the weird way assignments uses JSON
    $parametersTemp = Get-DeepClone $assignmentObj.parameters -AsHashTable
    $parameters = @{}
    foreach ($parameterName in $parametersTemp.Keys) {
        $value = $parametersTemp.$parameterName
        $parameters.$parameterName = @{
            value = $value
        }
    }

    # Build the REST API body
    $assignment = @{
        identity   = $assignmentObj.identity
        properties = @{
            policyDefinitionId = $assignmentObj.policyDefinitionId
            displayName        = $assignmentObj.displayName
            description        = $assignmentObj.description
            metadata           = $assignmentObj.metadata
            enforcementMode    = $assignmentObj.enforcementMode
            notScopes          = $assignmentObj.notScopes
        }
    }
    if ($assignmentObj.identityRequired) {
        $assignment.location = $assignmentObj.managedIdentityLocation
    }
    if ($parameters.psbase.Count -gt 0) {
        $assignment.properties.parameters = $parameters
    }
    if ($assignmentObj.nonComplianceMessages) {
        $assignment.properties.nonComplianceMessages = $assignmentObj.nonComplianceMessages
    }
    if ($assignmentObj.overrides) {
        $assignment.properties.overrides = $assignmentObj.overrides
    }
    if ($assignmentObj.resourceSelectors) {
        $assignment.properties.resourceSelectors = $assignmentObj.resourceSelectors
    }

    # Invoke the REST API
    $assignmentJson = ConvertTo-Json $assignment -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($assignmentObj.id)?api-version=2022-06-01" -Method PUT -Payload $assignmentJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -ne 201) {
        $content = $response.Content
        Write-Information "assignment: $assignmentJson"
        Write-Error "Assignment error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $displayName
}
