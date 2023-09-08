function Set-AzPolicyExemptionRestMethod {
    [CmdletBinding()]
    param (
        [PSCustomObject] $ExemptionObj
    )

    # Write log info
    $displayName = $ExemptionObj.displayName
    $id = $ExemptionObj.id
    Write-Information "$displayName($id)"

    # Build the REST API body
    $properties = @{
        policyAssignmentId           = $ExemptionObj.policyAssignmentId
        exemptionCategory            = $ExemptionObj.exemptionCategory
        assignmentScopeValidation    = $ExemptionObj.assignmentScopeValidation
        displayName                  = $ExemptionObj.displayName
        description                  = $ExemptionObj.description
        expiresOn                    = $ExemptionObj.expiresOn
        metadata                     = $ExemptionObj.metadata
        policyDefinitionReferenceIds = $ExemptionObj.policyDefinitionReferenceIds
        resourceSelectors            = $ExemptionObj.resourceSelectors
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
}
