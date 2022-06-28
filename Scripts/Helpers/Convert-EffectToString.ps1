#Requires -PSEdition Core

function Convert-EffectToString {
    param (
        [string] $effect, 
        [array] $allowedValues,
        [bool] $isParameterized,
        [switch] $Markdown
    )

    [string] $text = ""
    $effectShort = Convert-EffectToShortForm -effect $effect
    if ($Markdown.IsPresent) {
        $text = "**$effectShort**"
        if ($isParameterized) {
            foreach ($allowed in $allowedValues) {
                if ($allowed -ne $effect) {
                    $effectShort = Convert-EffectToShortForm -effect $allowed
                    $text += "<br/>*$effectShort*"
                }
            }
        }
    }
    else {
        $text += $effectShort
        if ($isParameterized) {
            foreach ($allowed in $allowedValues) {
                if ($allowed -ne $effect) {
                    $effectShort = Convert-EffectToShortForm -effect $allowed
                    $text += "\n$effectShort"
                }
            }
        }
    }
    return $text
}
