function Convert-AllowedEffectsToCsvString {
    param (
        $DefaultEffect,
        [bool] $IsEffectParameterized,
        $EffectAllowedValues,
        $EffectAllowedOverrides,
        [string] $InCellSeparator1,
        [string] $InCellSeparator2
    )

    $allowedList = @()
    $prefix = "default"
    if ($IsEffectParameterized -and $EffectAllowedValues.Count -gt 1) {
        $allowedList = $EffectAllowedValues
        $prefix = "parameter"
    }
    elseif ($EffectAllowedOverrides.Count -gt 1) {
        $allowedList = $EffectAllowedOverrides
        $prefix = "override"
    }
    elseif ($null -ne $DefaultEffect) {
        $prefix = "default"
        $allowedList = @( $DefaultEffect )
    }
    else {
        $prefix = "none"
        $allowedList = @()
        return "$(prefix)$($InCellSeparator1)No effect allowed$($InCellSeparator2)Error"
    }

    $effectArray = @()
    foreach ($effectValue in @( "Modify", "Append", "DenyAction", "Deny", "Audit", "Manual", "DeployIfNotExists", "AuditIfNotExists", "Disabled" )) {
        # sorted logicaly
        if ($allowedList -contains $effectValue) {
            $effectArray += $effectValue
        }
    }
    $effectAllowedText = "$($prefix)$($InCellSeparator1)$($effectArray -join $InCellSeparator2)"

    return $effectAllowedText
}
