
function Convert-ParametersToString {
    param (
        [hashtable] $Parameters,
        [string] $OutputType
    )

    [string] $text = ""
    [hashtable] $csvParametersHt = @{}
    if ($Parameters.psbase.Count -gt 0) {
        foreach ($parameterName in $Parameters.Keys) {
            $parameter = $Parameters.$parameterName
            $multiUse = $parameter.multiUse
            $isEffect = $parameter.isEffect
            $value = $parameter.value
            $defaultValue = $parameter.defaultValue
            $definition = $parameter.definition
            $policySetDisplayNames = $parameter.policySets
            if ($null -eq $value -and $null -eq $defaultValue) {
                $noDefault = $true
                $value = "++ no default ++"
            }
            elseif ($null -eq $value) {
                $value = $defaultValue
            }
            switch ($OutputType) {
                markdown {
                    if ($value -is [string]) {
                        $text += "<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*$parameterName = ``$value``*"
                    }
                    else {
                        $json = ConvertTo-Json $value -Depth 100 -Compress
                        $jsonTruncated = $json
                        if ($json.length -gt 40) {
                            $jsonTruncated = $json.substring(0, 40) + "..."
                        }
                        $text += "<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*$parameterName = ``$jsonTruncated``*"
                    }
                }
                markdownAssignment {
                    if (-not $isEffect) {
                        if ($value -is [string]) {
                            $text += "<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*$parameterName = ``$value``*"
                        }
                        else {
                            $json = ConvertTo-Json $value -Depth 100 -Compress
                            $jsonTruncated = $json
                            if ($json.length -gt 40) {
                                $jsonTruncated = $json.substring(0, 40) + "..."
                            }
                            $text += "<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*$parameterName = ``$jsonTruncated``*"
                        }
                    }
                }
                csvValues {
                    if (-not ($multiUse -or $isEffect)) {
                        $null = $csvParametersHt.Add($parameterName, $value)
                    }
                }
                csvDefinitions {
                    if (-not $multiUse) {
                        $null = $csvParametersHt.Add($parameterName, $definition)
                    }
                }
                jsonc {
                    $parameterString = "`"$($parameterName)`": $(ConvertTo-Json $value -Depth 100 -Compress), // '$($policySetDisplayNames -Join "', '")'"
                    if ($multiUse) {
                        $text += "`n    // Multi-use: ($parameterString)"
                    }
                    elseif ($noDefault) {
                        $text += "`n    // No-default: ($parameterString)"
                    }
                    else {
                        $text += "`n    $($parameterString),"
                    }
                }
                Default {
                    Write-Error "Convert-ParametersToString: unknown outputType '$OutputType'" -ErrorAction Stop
                }
            }
        }
        if (($OutputType -eq "csvValues" -or $OutputType -eq "csvDefinitions") -and $csvParametersHt.psbase.Count -gt 0) {
            $text = ConvertTo-Json $csvParametersHt -Depth 100 -Compress
        }
    }
    return $text
}
