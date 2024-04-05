function Confirm-EffectIsAllowed {
    [CmdletBinding()]
    param (
        $Effect,
        $AllowedEffects
    )

    foreach ($allowedEffect in $AllowedEffects) {
        if ($Effect -eq $allowedEffect) {
            return $allowedEffect # fixes potentially wrong case, or keeps the original case
        }
    }
    return $null
}