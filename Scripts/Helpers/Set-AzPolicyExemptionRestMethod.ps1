function Set-AzPolicyExemptionRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $exemptionObj
    )

    # Write log info
    $displayName = $exemptionObj.displayName
    Write-Information $displayName

    # Build the REST API body
    $properties = @{
        policyAssignmentId        = $exemptionObj.policyAssignmentId
        exemptionCategory         = $exemptionObj.exemptionCategory
        assignmentScopeValidation = $exemptionObj.assignmentScopeValidation
    }
    if ($exemptionObj.displayName -and $exemptionObj.displayName.Length -gt 0) {
        $properties.displayName = $exemptionObj.displayName
    }
    if ($exemptionObj.description -and $exemptionObj.description.Length -gt 0) {
        $properties.description = $exemptionObj.description
    }
    if ($exemptionObj.expiresOn) {
        $properties.expiresOn = $exemptionObj.expiresOn
    }
    if ($exemptionObj.metadata -and $exemptionObj.metadata.base.Count -gt 0) {
        $properties.metadata = $exemptionObj.metadata
    }
    if ($exemptionObj.policyDefinitionReferenceIds) {
        $properties.policyDefinitionReferenceIds = $exemptionObj.policyDefinitionReferenceIds
    }
    if ($exemptionObj.resourceSelectors) {
        $properties.resourceSelectors = $exemptionObj.resourceSelectors
    }
    Remove-NullFields $properties
    $exemption = @{
        properties = $properties
    }

    # Invoke the REST API
    $exemptionJson = ConvertTo-Json $exemption -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($exemptionObj.id)?api-version=2022-07-01-preview" -Method PUT -Payload $exemptionJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Policy Exemption error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $displayName
}
