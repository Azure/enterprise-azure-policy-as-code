function Convert-EffectToString {
    param (
        [string] $Effect,
        [array] $AllowedValues,
        [switch] $Markdown
    )

    [string] $text = ""
    if ($null -ne $Effect) {
        if ($Markdown) {
            if ($AllowedValues.Count -eq 1) {
                $text = "***$Effect***"
            }
            else {
                $text = "**$Effect**"
            }
            foreach ($allowed in $AllowedValues) {
                if ($allowed -cne $Effect) {
                    $text += "<br/>*$allowed*"
                }
            }
        }
        else {
            $text += $Effect
            foreach ($allowed in $AllowedValues) {
                if ($allowed -cne $Effect) {
                    $text += ", $allowed"
                }
            }
        }
    }
    return $text
}
