function Convert-PolicySetParameterEffectValues {
    <#
    .SYNOPSIS
        Normalizes effect parameter values in policy set definition parameters to proper title case.
    .DESCRIPTION
        The Azure Policy API enforces case-sensitive validation for effect parameter values.
        Some policy library sources (e.g. the Azure Landing Zones library) may define
        defaultValue or allowedValues entries with lowercase effect strings such as 'deny'
        instead of the required 'Deny'. This function normalizes all string values that
        match a known policy effect (case-insensitively) to the correct title-case form,
        preventing API errors like "The value 'deny' is not allowed for policy parameter
        'effect' ... The allowed values are 'Audit, Deny, Disabled'."
    .PARAMETER Parameters
        The PSCustomObject representing the parameters block of a policy set definition.
        The object is modified in place.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Parameters
    )

    if ($null -eq $Parameters) {
        return
    }

    $knownEffects = @{
        "deny"              = "Deny"
        "audit"             = "Audit"
        "disabled"          = "Disabled"
        "modify"            = "Modify"
        "append"            = "Append"
        "deployifnotexists" = "DeployIfNotExists"
        "auditifnotexists"  = "AuditIfNotExists"
        "manual"            = "Manual"
        "denyaction"        = "DenyAction"
    }

    foreach ($paramName in $Parameters.PSObject.Properties.Name) {
        $param = $Parameters.$paramName

        if ($null -ne $param.defaultValue -and $param.defaultValue -is [string]) {
            $lowerValue = $param.defaultValue.ToLower()
            if ($knownEffects.ContainsKey($lowerValue) -and $param.defaultValue -cne $knownEffects[$lowerValue]) {
                $param.defaultValue = $knownEffects[$lowerValue]
            }
        }

        if ($null -ne $param.allowedValues) {
            $normalizedAllowed = @(foreach ($val in $param.allowedValues) {
                if ($val -is [string]) {
                    $lowerVal = $val.ToLower()
                    if ($knownEffects.ContainsKey($lowerVal)) { $knownEffects[$lowerVal] } else { $val }
                }
                else {
                    $val
                }
            })
            $param.allowedValues = $normalizedAllowed
        }
    }
}
