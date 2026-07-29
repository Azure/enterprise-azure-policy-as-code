function Set-AzPolicyEnrollmentRestMethod {
    [CmdletBinding()]
    param (
        $EnrollmentObj,
        $ApiVersion
    )

    Write-ModernStatus -Message "Setting policy enrollment: $($EnrollmentObj.displayName)" -Status "info" -Indent 2

    $properties = @{
        assignmentScopeValidation    = $EnrollmentObj.assignmentScopeValidation
        description                  = $EnrollmentObj.description
        displayName                  = $EnrollmentObj.displayName
        metadata                     = $EnrollmentObj.metadata
        policyAssignmentId           = $EnrollmentObj.policyAssignmentId
        policyDefinitionReferenceIds = $EnrollmentObj.policyDefinitionReferenceIds
        resourceSelectors            = $EnrollmentObj.resourceSelectors
    }
    Remove-NullFields $properties
    $payload = ConvertTo-Json @{ properties = $properties } -Depth 100 -Compress
    $response = Invoke-AzRestMethod -Path "$($EnrollmentObj.id)?api-version=$ApiVersion" -Method PUT -Payload $payload

    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        throw "Policy Enrollment deployment failed: $($response.StatusCode) -- $($response.Content)"
    }
}