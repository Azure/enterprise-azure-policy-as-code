function Set-AzPolicyExemptionRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $ExemptionObj
    )

    # Write log info
    $DisplayName = $ExemptionObj.displayName
    Write-Information $DisplayName

    # Build the REST API body
    $properties = @{
        policyAssignmentId        = $ExemptionObj.policyAssignmentId
        exemptionCategory         = $ExemptionObj.exemptionCategory
        assignmentScopeValidation = $ExemptionObj.assignmentScopeValidation
    }
    if ($ExemptionObj.displayName -and $ExemptionObj.displayName.Length -gt 0) {
        $properties.displayName = $ExemptionObj.displayName
    }
    if ($ExemptionObj.description -and $ExemptionObj.description.Length -gt 0) {
        $properties.description = $ExemptionObj.description
    }
    if ($ExemptionObj.expiresOn) {
        $properties.expiresOn = $ExemptionObj.expiresOn
    }
    if ($ExemptionObj.metadata -and $ExemptionObj.metadata.base.Count -gt 0) {
        $properties.metadata = $ExemptionObj.metadata
    }
    if ($ExemptionObj.policyDefinitionReferenceIds) {
        $properties.policyDefinitionReferenceIds = $ExemptionObj.policyDefinitionReferenceIds
    }
    if ($ExemptionObj.resourceSelectors) {
        $properties.resourceSelectors = $ExemptionObj.resourceSelectors
    }
    Remove-NullFields $properties
    $exemption = @{
        properties = $properties
    }

    # Invoke the REST API
    $exemptionJson = ConvertTo-Json $exemption -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($ExemptionObj.id)?api-version=2022-07-01-preview" -Method PUT -Payload $exemptionJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Policy Exemption error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    return $DisplayName
}
