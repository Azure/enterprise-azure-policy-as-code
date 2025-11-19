function Convert-OrdinalToEffectDisplayName {
    param (
        [string] $Ordinal
    )

    $sortOrdinal2effect = @(
        "Policy effects Modify, Append and DeployIfNotExists(DINE)",
        "Policy effects Deny",
        "Policy effects Audit",
        "Policy effects AuditIfNotExists(AINE)",
        "Policy effects Disabled"
    )

    $displayName = "Unknown"
    if ($Ordinal -ge 0 -and $Ordinal -lt $sortOrdinal2effect.Count) {
        $displayName = $sortOrdinal2effect[$Ordinal]
        $link = $displayName.ToLower() -replace "[ ]", "-" -replace "[\()\,]", "_"
    }
    return $displayName, $link
}
