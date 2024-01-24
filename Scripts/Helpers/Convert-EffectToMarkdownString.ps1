function Convert-EffectToMarkdownString {
    param (
        [string] $Effect,
        [array] $AllowedValues
    )

    [string] $text = ""
    if ($null -ne $Effect) {
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
    return $text
}
