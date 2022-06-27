#Requires -PSEdition Core

function Convert-EffectToShortForm {
    param (
        [string] $effect
    )
    
    $effectShort = switch ($effect) {
        DeployifNotExists { "DINE" }
        AuditIfnotExists { "AINE" }
        default { $switch.Current }
    }
    return $effectShort
}
