function Convert-EffectToCsvString {
    param (
        # Parameter help description
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "The effect to convert to a CSV string")]
        [string] $Effect
    )
    
    # Convert the effect to a CSV string to fix mixed case sensitivity
    $effectValueText = switch ($Effect) {
        "Modify" { "Modify" }
        "Append" { "Append" }
        "DenyAction" { "DenyAction" }
        "Deny" { "Deny" }
        "Audit" { "Audit" }
        "Manual" { "Manual" }
        "DeployIfNotExists" { "DeployIfNotExists" }
        "AuditIfNotExists" { "AuditIfNotExists" }
        "Disabled" { "Disabled" }
        default { "Error" }
    }
    return $effectValueText
}
