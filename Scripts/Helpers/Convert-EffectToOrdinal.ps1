function Convert-EffectToOrdinal {
    param (
        [string] $Effect
    )

    $ordinal = switch ($Effect) {
        "Modify" { 0 }
        "Append" { 1 }
        "DeployIfNotExists" { 2 }
        "DenyAction" { 3 }
        "Deny" { 4 }
        "Audit" { 5 }
        "Manual" { 6 }
        "AuditIfNotExists" { 7 }
        "Disabled" { 8 }
        default { 98 }
    }
    return $ordinal
}
