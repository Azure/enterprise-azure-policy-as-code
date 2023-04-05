function Convert-OrdinalToEffectDisplayName {
    param (
        [string] $ordinal
    )

    $sortOrdinal2effect = @(
        "Policy effects Modify, Append and DeployIfNotExists(DINE)",
        "Policy effects Deny",
        "Policy effects Audit",
        "Policy effects AuditIfNotExists(AINE)",
        "Policy effects Disabled"
    )

    $displayName = "Unknown"
    if ($ordinal -ge 0 -and $ordinal -lt $sortOrdinal2effect.Count) {
        $displayName = $sortOrdinal2effect[$ordinal]
        $link = $displayName.ToLower() -replace "[ ]", "-" -replace "[\()\,]", "_"
    }
    return $displayName, $link
}