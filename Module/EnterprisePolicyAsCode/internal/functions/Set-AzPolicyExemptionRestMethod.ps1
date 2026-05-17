function Set-AzPolicyExemptionRestMethod {
    [CmdletBinding()]
    param (
        $ExemptionObj,
        $ApiVersion,
        $FailOnExemptionError,
        # Minimum API version required for identity-based exemption selector kinds
        # (userPrincipalId, groupPrincipalId). Added in 2024-12-01-preview.
        $IdentityApiVersion = "2024-12-01-preview"
    )

    # Detect identity-based exemption selectors. When present, auto-upgrade the
    # API version because the previously default 2022-07-01-preview does not
    # define userPrincipalId / groupPrincipalId in the Selector.kind enum.
    $effectiveApiVersion = $ApiVersion
    $hasIdentitySelector = $false
    if ($ExemptionObj.resourceSelectors) {
        foreach ($rs in $ExemptionObj.resourceSelectors) {
            if ($null -ne $rs.selectors) {
                foreach ($s in $rs.selectors) {
                    if ($s.kind -eq "userPrincipalId" -or $s.kind -eq "groupPrincipalId") {
                        $hasIdentitySelector = $true
                        break
                    }
                }
            }
            if ($hasIdentitySelector) { break }
        }
    }
    if ($hasIdentitySelector -and $effectiveApiVersion -ne $IdentityApiVersion) {
        $effectiveApiVersion = $IdentityApiVersion
    }

    # Write log info
    Write-ModernStatus -Message "Setting policy at scope: $($ExemptionObj.scope)" -Status "info" -Indent 4

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
    $response = Invoke-AzRestMethod -Path "$($ExemptionObj.id)?api-version=$effectiveApiVersion" -Method PUT -Payload $exemptionJson

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        if ($content.Contains("ScopeLocked", [StringComparison]::InvariantCultureIgnoreCase)) {
            Write-Warning "Ignoring scope locked error: $($statusCode) -- $($content)"
        }
        else {
            if ($FailOnExemptionError -eq $true) {
                Write-Error "Error, failing deployment: $($statusCode) -- $($content)"
                exit 1
            }
            Write-Warning "Error, continue deployment: $($statusCode) -- $($content)"
        }
        if ($statusCode -eq 404) {
            Write-Warning "Please verify Policy Exemptions are valid"
            exit 1
        }
    }
}
