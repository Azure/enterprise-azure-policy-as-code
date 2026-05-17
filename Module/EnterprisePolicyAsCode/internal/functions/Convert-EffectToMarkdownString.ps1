function Convert-EffectToMarkdownString {
    param (
        [string] $Effect,
        [array] $AllowedValues,
        [string] $InTableBreak = "<br/>"
    )

    [string] $text = ""
    if ($null -ne $Effect) {
        $text = "**$Effect**"
        foreach ($allowed in $AllowedValues) {
            if ($allowed -cne $Effect) {
                $text += "$($InTableBreak)$($allowed)"
            }
        }
    }
    return $text
}
