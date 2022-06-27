#Requires -PSEdition Core


function Convert-ParametersToString {
    param (
        [hashtable] $parameters,
        [string] $shortName = "",
        [switch] $Markdown
    )

    [string] $text = ""
    if ($parameters.Count -gt 0) {
        [string[]] $parameterList = @()
        foreach ($parameterName in $parameters.Keys) {
            $parameter = $parameters.$parameterName
            $value = $parameter.value
            if ($null -eq $value) {
                $value = "undefined"
                if ($parameter.defaultValue) {
                    $value = $parameter.defaultValue
                }

            }
            $value = ConvertTo-Json $value -Compress
            $parameterList += "$parameterName=``$value``"
        }
        if ($Markdown.IsPresent) {
            $break = "<br/>"
            if ($parameterList.Count -gt 1) {
                $text += "<br/>**$shortName**"
                $break = "<br/>`    "
            }
            else {
                $text += "<br/>**$shortName**: "
                $break = ""
            }
            foreach ($parameterText in $parameterList) {
                $text += "$break*$parameterText*"
            }
        }
        else {
            $newLine = ""
            foreach ($parameterText in $parameterList) {
                $text += "$newLine$parameterText"
                $newLine = "\n"
            }
        }
    }
    else {
        if (-not $Markdown.IsPresent) {
            $text = "n/a"
        }
    }
    return $text
}
