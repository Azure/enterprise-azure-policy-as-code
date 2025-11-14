function Convert-PolicyToDetails {
    [CmdletBinding()]
    param (
        $PolicyId,
        $PolicyDefinition,
        $PolicyDetails
    )

    $properties = Get-PolicyResourceProperties -PolicyResource $PolicyDefinition
    $category = "Unknown"
    if ($properties.metadata -and $properties.metadata.category) {
        $category = $properties.metadata.category
    }
    $effectRawValue = $properties.policyRule.then.effect
    $found, $effectParameterName = Get-ParameterNameFromValueString -ParamValue $effectRawValue

    $effectValue = $null
    $effectDefault = $null
    $effectAllowedValues = @()
    $effectAllowedOverrides = @()
    $effectReason = "Policy No Default"
    $parameters = $properties.parameters | ConvertTo-HashTable
    if ($found) {
        if ($parameters.Keys -contains $effectParameterName) {
            $effectParameter = $parameters.$effectParameterName
            if ($effectParameter.defaultValue) {
                $effectValue = $effectParameter.defaultValue
                $effectDefault = $effectParameter.defaultValue
                $effectReason = "Policy Default"
            }
        }
        else {
            Write-Error "Policy uses parameter '$effectParameterName' for the effect not defined in the parameters. This should not be possible!" -ErrorAction Stop
        }
        if ($effectParameter.allowedValues) {
            $effectAllowedValues = $effectParameter.allowedValues
            $effectAllowedOverrides = $effectParameter.allowedValues
        }
    }
    else {
        # Fixed value
        $effectValue = $effectRawValue
        $effectDefault = $effectRawValue
        $effectAllowedValues = @( $effectDefault )
        $effectReason = "Policy Fixed"
    }
    if ($effectAllowedOverrides.Count -eq 0) {
        # Analyze Policy
        $then = $properties.policyRule.then
        $details = $then.details
        $denyAction = $details -and $details.actionNames
        $auditIfNotExists = $details -and $details.existenceCondition
        $deployIfNotExists = $auditIfNotExists -and $details.deployment
        $modify = $details -and $details.operations
        $manual = $details -and $details.defaultState
        $append = $details -and $details -is [array]

        if ($denyAction) {
            $effectAllowedOverrides = @("Disabled", "DenyAction")
        }
        elseif ($manual) {
            $effectAllowedOverrides = @("Disabled", "Manual")
        }
        elseif ($deployIfNotExists) {
            $effectAllowedOverrides = @("Disabled", "AuditIfNotExists", "DeployIfNotExists")
        }
        elseif ($auditIfNotExists) {
            $effectAllowedOverrides = @("Disabled", "AuditIfNotExists")
        }
        elseif ($modify) {
            $effectAllowedOverrides = @("Disabled", "Audit", "Modify")
        }
        elseif ($append) {
            $effectAllowedOverrides = @("Disabled", "Audit", "Deny", "Append")
        }
        else {
            if ($effectReason -eq "Policy Fixed") {
                if ($effectValue -eq "deny") {
                    $effectAllowedOverrides = @("Disabled", "Audit", "Deny")
                }
                elseif ($effectValue -eq "audit") {
                    $effectAllowedOverrides = @("Disabled", "Audit", "Deny") # Safe assumption if Audit or Disabled - deny is a valid case as well - see ALZ deny-unmanageddisk
                }
                else {
                    # Disabled: very weird for hard coded
                    $effectAllowedOverrides = @("Disabled", "Audit") # Safe assumption
                }
            }
            else {
                if ($effectDefault -eq "deny") {
                    $effectAllowedOverrides = @("Disabled", "Audit", "Deny")
                }
                else {
                    $effectAllowedOverrides = @("Disabled", "Audit", "Deny") # Guess, could be @("Disabled", "Audit")
                }
            }
        }
    }

    $displayName = $properties.displayName
    if (-not $displayName -or $displayName -eq "") {
        $displayName = $PolicyDefinition.name
    }

    $description = $properties.description
    if (-not $description) {
        $description = ""
    }

    $parameterDefinitions = @{}
    foreach ($parameterName in $parameters.Keys) {
        $parameter = $parameters.$parameterName
        $parameterDefinition = @{
            isEffect     = $parameterName -eq $effectParameterName
            value        = $null
            defaultValue = $parameter.defaultValue
            definition   = $parameter
        }
        $null = $parameterDefinitions.Add($parameterName, $parameterDefinition)
    }

    $isDeprecated = $false
    $version = "0.0.0"
    if ($properties.metadata -and $properties.metadata.version) {
        $version = $properties.metadata.version
        if ($version.Contains("deprecated", [StringComparison]::InvariantCultureIgnoreCase)) {
            $isDeprecated = $true
        }
    }

    $name = $PolicyDefinition.name
    $policyDetail = @{
        id                     = $PolicyId
        name                   = $name
        displayName            = $displayName
        description            = $description
        policyType             = $properties.policyType
        category               = $category
        version                = $version
        isDeprecated           = $isDeprecated
        effectParameterName    = $effectParameterName
        effectValue            = $effectValue
        effectDefault          = $effectDefault
        effectAllowedValues    = $effectAllowedValues
        effectAllowedOverrides = $effectAllowedOverrides
        effectReason           = $effectReason
        parameters             = $parameterDefinitions
    }
    $null = $PolicyDetails.Add($PolicyId, $policyDetail)
}
