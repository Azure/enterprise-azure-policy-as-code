#Requires -PSEdition Core

function Convert-EffectToString {
    param (
        [string] $effect,
        [array] $allowedValues,
        [switch] $Markdown
    )

    [string] $text = ""
    $effectShort = Convert-EffectToShortForm -effect $effect
    if ($Markdown.IsPresent) {
        if ($allowedValues.Count -eq 1) {
            $text = "***$effectShort***"
        }
        else {
            $text = "**$effectShort**"
        }
        foreach ($allowed in $allowedValues) {
            if ($allowed -cne $effect) {
                $effectShort = Convert-EffectToShortForm -effect $allowed
                $text += "<br/>*$effectShort*"
            }
        }
    }
    else {
        $text += $effectShort
        foreach ($allowed in $allowedValues) {
            if ($allowed -cne $effect) {
                $effectShort = Convert-EffectToShortForm -effect $allowed
                $text += "\n$effectShort"
            }
        }
    }
    return $text
}
