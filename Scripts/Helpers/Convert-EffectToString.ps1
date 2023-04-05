function Convert-EffectToString {
    param (
        [string] $effect,
        [array] $allowedValues,
        [switch] $Markdown
    )

    [string] $text = ""
    if ($null -ne $effect) {
        if ($Markdown) {
            if ($allowedValues.Count -eq 1) {
                $text = "***$effect***"
            }
            else {
                $text = "**$effect**"
            }
            foreach ($allowed in $allowedValues) {
                if ($allowed -cne $effect) {
                    $text += "<br/>*$allowed*"
                }
            }
        }
        else {
            $text += $effect
            foreach ($allowed in $allowedValues) {
                if ($allowed -cne $effect) {
                    $text += ", $allowed"
                }
            }
        }
    }
    return $text
}
