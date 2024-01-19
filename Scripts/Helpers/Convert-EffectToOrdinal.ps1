function Convert-EffectToOrdinal {
    param (
        [string] $Effect
    )

    $ordinal = switch ($Effect) {
        "Modify" { $ordinal = 0 }
        "Append" { $ordinal = 0 }
        "DeployIfNotExists" { $ordinal = 0 }
        "Deny" { $ordinal = 1 }
        "Audit" { $ordinal = 2 }
        "Manual" { $ordinal = 2 }
        "AuditIfNotExists" { $ordinal = 2 }
        "Disabled" { $ordinal = 9 }
        default { $ordinal = 9 }
    }
    return $ordinal
}
