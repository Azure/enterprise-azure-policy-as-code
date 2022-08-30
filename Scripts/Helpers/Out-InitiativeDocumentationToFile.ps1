#Requires -PSEdition Core

function Out-InitiativeDocumentationToFile {
    [CmdletBinding()]
    param (
        [string] $outputPath,
        [string] $fileNameStem,
        [string] $title,
        [array] $itemList,
        [array] $environmentColumnsInCsv,
        [hashtable] $initiativeInfos,
        [hashtable] $flatPolicyList
    )

    Write-Information "Generating '$title' documentation files '$fileNameStem'."

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $headerAndToc = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $body = [System.Collections.Generic.List[string]]::new()

    $null = $headerAndToc.Add("# $title`n")
    $null = $headerAndToc.Add("Auto-generated Policy effect documentation for Initiatives grouped by Effect and sorted by Policy category and Policy display name.`n")
    $null = $headerAndToc.Add("## Table of contents`n")

    $null = $headerAndToc.Add("- [Initiatives](#initiatives)")
    $null = $body.Add("`n## <a id=`"initiatives`"></a>Initiatives`n")
    $addedTableHeader = ""
    $addedTableDivider = ""
    foreach ($item in $itemList) {
        $shortName = $item.shortName
        $initiativeId = $item.initiativeId
        $initiativeInfo = $initiativeInfos.$initiativeId
        $null = $body.Add("### $($shortName)`n")
        $null = $body.Add("- Display name: $($initiativeInfo.displayName)")
        $null = $body.Add("- Type: $($initiativeInfo.policyType)")
        $null = $body.Add("- Category: $($initiativeInfo.category)`n")
        $null = $body.Add("$($initiativeInfo.description)`n")

        $addedTableHeader += " $shortName |"
        $addedTableDivider += " :-------- |"
    }
    $null = $headerAndToc.Add("- [Policies](#policies)")
    $null = $body.Add("`n<br/>`n`n## <a id='policies'></a>Policies`n`n<br/>`n")
    $null = $body.Add("| Category | Policy |$addedTableHeader")
    $null = $body.Add("| :------- | :----- |$addedTableDivider")

    $flatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        $initiativeList = $_.initiativeList
        $addedEffectColumns = ""
        $addedRows = ""
        foreach ($item in $itemList) {
            $shortName = $item.shortName
            if ($initiativeList.ContainsKey($shortName)) {
                $perInitiative = $initiativeList.$shortName
                $effectValue = $perInitiative.effectValue
                $effectAllowedValues = $perInitiative.effectAllowedValues
                $text = Convert-EffectToString `
                    -effect $effectValue `
                    -allowedValues $effectAllowedValues `
                    -Markdown
                $addedEffectColumns += " $text |"

                [array] $groupNames = $perInitiative.groupNames
                $parameters = $perInitiative.parameters
                if ($parameters.Count -gt 0 -or $groupNames.Count -gt 0) {
                    $addedRows += "<br/>*$($perInitiative.displayName):*"
                    $text = Convert-ParametersToString -parameters $parameters -outputType "markdown"
                    $addedRows += $text
                    foreach ($groupName in $groupNames) {
                        $addedRows += "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$groupName"
                    }
                }
            }
            else {
                $addedEffectColumns += "  |"
            }
        }
        $referencePathString = ""
        if ($_.referencePath -ne "") {
            $referencePathString = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;referencePath: ``$($_.referencePath)``<br/>"
        }
        $null = $body.Add("| $($_.category) | **$($_.displayName)**<br/>$($referencePathString)$($_.description)$($addedRows) |$addedEffectColumns")
    }
    $null = $headerAndToc.Add("`n<br/>")
    $null = $allLines.AddRange($headerAndToc)
    $null = $allLines.AddRange($body)

    # Output file
    $outputFilePath = "$($outputPath -replace '[/\\]$','')/$fileNameStem.md"
    $allLines | Out-File $outputFilePath -Force

    #endregion Markdown

    #region CSV

    $outputParameterFiles = $null -ne $environmentColumnsInCsv -and $environmentColumnsInCsv.Length -gt 0
    if (-not $outputParameterFiles) {
        Write-Information "No environmentColumnsInCsv '$environmentColumnsInCsv' specified - do not output parameters CSV file."
    }

    $csvOutputTypes = @( "details" )
    if ($outputParameterFiles) {
        $csvOutputTypes = @( "details", "parameters" )
    }

    [System.Collections.ArrayList] $allRows = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList] $columnHeaders = [System.Collections.ArrayList]::new()
    foreach ($csvOutputType in $csvOutputTypes) {
        $fullOutput = $csvOutputType -eq "details"

        $allRows.Clear()
        $columnHeaders.Clear()
        # Create header rows for CSV
        $null = $columnHeaders.AddRange(@("name", "referencePath", "category", "displayName", "description" ))
        if ($fullOutput) {
            $null = $columnHeaders.Add("groupNames")
        }
        $null = $columnHeaders.Add("allowedEffects")

        if ($fullOutput) {
            foreach ($item in $itemList) {
                $shortName = $item.shortName
                $null = $columnHeaders.Add("$($shortName)-EffectDefault")
            }
            foreach ($item in $itemList) {
                $shortName = $item.shortName
                $null = $columnHeaders.Add("$($shortName)-ParameterDefinitions")
            }
        }
        else {
            foreach ($environmentCategory in $environmentColumnsInCsv) {
                $null = $columnHeaders.Add("$($environmentCategory)_Effect")
            }
            foreach ($environmentCategory in $environmentColumnsInCsv) {
                $null = $columnHeaders.Add("$($environmentCategory)_Parameters")
            }
        }


        # Content rows
        $flatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {

            # Initialize row - with empty strings
            $rowObj = [ordered]@{}
            foreach ($key in $columnHeaders) { $null = $rowObj.Add($key, "") }

            # Cache loop values
            $effectAllowedValues = $_.effectAllowedValues
            $initiativeList = $_.initiativeList
            $groupNames = $_.groupNames
            $effectDefault = $_.effectDefault

            # Build common columns
            $rowObj.name = $_.name
            $rowObj.referencePath = $_.referencePath
            $rowObj.category = $_.category
            $rowObj.displayName = $_.displayName
            $rowObj.description = $_.description
            if ($_.effectAllowedValues.Count -gt 0) {
                $rowObj.allowedEffects = $effectAllowedValues.Keys -join ", "
            }
            # $rowObj.initiativeList = $initiativeAndEffectReasonList.Values -join ", "
            if ($fullOutput) {
                if ($_.groupNames.Count -gt 0) {
                    $rowObj.groupNames = $groupNames.Keys -join ", "
                }
            }

            # Per environment columns (repeat each per environmnet if it exists)
            $parameters = $_.parameters
            if ($fullOutput) {
                foreach ($item in $itemList) {
                    $shortName = $item.shortName
                    # Per Initiative parameter definition columns
                    if ($initiativeList.ContainsKey($shortName)) {
                        $perInitiative = $initiativeList.$shortName
                        $rowObj["$($shortName)-EffectDefault"] = $perInitiative.effectDefaultString
                        if ($null -ne $perInitiative.parameters) {
                            $parameters = $perInitiative.parameters
                            $parametersDefinitionString = Convert-ParametersToString -parameters $parameters -outputType "csvDefinitions"
                            $rowObj["$($shortName)-ParameterDefinitions"] = $parametersDefinitionString
                        }
                    }
                }
            }
            else {
                $parametersValueString = Convert-ParametersToString -parameters $parameters -outputType "csvValues"
                foreach ($environmentCategory in $environmentColumnsInCsv) {
                    $rowObj["$($environmentCategory)_Effect"] = $effectDefault
                    $rowObj["$($environmentCategory)_Parameters"] = $parametersValueString
                }

            }

            # Add row to spreadsheet
            $null = $allRows.Add($rowObj)
        }
        # Output file
        $outputFilePath = "$($outputPath -replace '[/\\]$','')/$($fileNameStem)-$($csvOutputType).csv"
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force
    }

    #endregion CSV

    #region Parameters JSON

    $sb = [System.Text.StringBuilder]::new()
    [void] $sb.Append("{")
    [void] $sb.Append("`n  `"parameters`": {")
    $flatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        $initiativeList = $_.initiativeList
        $referencePath = $_.referencePath
        $displayName = $_.displayName
        $category = $_.category

        [void] $sb.Append("`n    // ")
        [void] $sb.Append("`n    // -----------------------------------------------------------------------------------------------------------------------------")
        [void] $sb.Append("`n    // $($category) -- $($displayName)")
        if ($referencePath -ne "") {
            [void] $sb.Append("`n    //     referencePath: $($referencePath)")
        }
        foreach ($item in $itemList) {
            $shortName = $item.shortName
            if ($initiativeList.ContainsKey($shortName)) {
                $perInitiative = $initiativeList.$shortName
                $initiativeDisplayName = $perInitiative.displayName
                if ($perInitiative.isEffectParameterized) {
                    [void] $sb.Append("`n    //   $($initiativeDisplayName): $($perInitiative.effectDefault) ($($perInitiative.effectParameterName))")
                }
                else {
                    [void] $sb.Append("`n    //   $($initiativeDisplayName): $($perInitiative.effectDefault) ($($perInitiative.effectReason))")
                }
            }
        }
        [void] $sb.Append("`n    // -----------------------------------------------------------------------------------------------------------------------------")
        $parameterText = Convert-ParametersToString -parameters $_.parameters -outputType "jsonc"
        [void] $sb.Append($parameterText)
    }
    [void] $sb.Append("`n  }")
    [void] $sb.Append("`n}")

    # Output file
    $outputFilePath = "$($outputPath -replace '[/\\]$', '')/$fileNameStem.jsonc"
    $sb.ToString() | Out-File $outputFilePath -Force

    #endregion

}
