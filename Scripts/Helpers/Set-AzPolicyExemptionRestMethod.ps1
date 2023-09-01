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
    $payload = ConvertTo-Json $exemption -Depth 100 -Compress
    $path = "$($id)?api-version=2022-07-01-preview"
    $objectName = "Policy Exemption"
    $null = Invoke-AzRestMethodWrapper -ObjectName $objectName -Path $path -Method PUT -Payload $payload
}
