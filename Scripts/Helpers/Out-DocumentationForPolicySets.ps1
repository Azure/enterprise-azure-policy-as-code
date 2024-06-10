function Out-DocumentationForPolicySets {
    [CmdletBinding()]
    param (
        [string] $OutputPath,
        [switch] $WindowsNewLineCells,
        $DocumentationSpecification,
        [array] $ItemList,
        [array] $EnvironmentColumnsInCsv,
        [hashtable] $PolicySetDetails,
        [hashtable] $FlatPolicyList,
        [switch] $IncludeManualPolicies
    )

    $fileNameStem = $DocumentationSpecification.fileNameStem
    $title = $DocumentationSpecification.title
    $environmentColumnsInCsv = $DocumentationSpecification.environmentColumnsInCsv


    Write-Information "Generating Policy Set documentation for '$title', files '$FileNameStem'."

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    $leadingHeadingHashtag = "#"
    if ($DocumentationSpecification.markdownAdoWiki) {
        $leadingHeadingHashtag = ""
        $null = $allLines.Add("[[_TOC_]]`n")
    }
    else {
        $null = $allLines.Add("# $title`n")
        if ($DocumentationSpecification.markdownAddToc) {
            $null = $allLines.Add("[[_TOC_]]`n")
        }
    }
    $null = $allLines.Add("Auto-generated Policy effect documentation for PolicySets grouped by Effect and sorted by Policy category and Policy display name.")
    $inTableAfterDisplayNameBreak = "<br/>"
    $inTableBreak = "<br/>"
    if ($DocumentationSpecification.markdownNoEmbeddedHtml) {
        $inTableAfterDisplayNameBreak = ": "
        $inTableBreak = ", "
    }

    #region Policy Set List
    $addedTableHeader = ""
    $addedTableDivider = ""
    $addedTableDividerParameters = ""
    $null = $allLines.Add("`n$leadingHeadingHashtag# Policy Set (Initiative) List`n")
    foreach ($item in $ItemList) {
        $shortName = $item.shortName
        $policySetId = $item.policySetId
        $policySetDetail = $PolicySetDetails.$policySetId
        $policySetDisplayName = $policySetDetail.displayName -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
        $policySetDescription = $policySetDetail.description -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
        $null = $allLines.Add("$leadingHeadingHashtag## $($shortName)`n")
        $null = $allLines.Add("- Display name: $($policySetDisplayName)`n")
        $null = $allLines.Add("- Type: $($policySetDetail.policyType)")
        $null = $allLines.Add("- Category: $($policySetDetail.category)`n")
        $null = $allLines.Add("$($policySetDescription)`n")

        $addedTableHeader += " $shortName |"
        $addedTableDivider += " :-------: |"
        $addedTableDividerParameters += " :------- |"
    }
    #endregion Policy Set List

    #region Policy Effects
    if ($DocumentationSpecification.markdownIncludeComplianceGroupNames) {
        $null = $allLines.Add("`n$leadingHeadingHashtag# Policy Effects by Policy`n")
        $null = $allLines.Add("| Category | Policy | Compliance |$addedTableHeader")
        $null = $allLines.Add("| :------- | :----- | :----------|$addedTableDivider")
    }
    else {
        $null = $allLines.Add("`n$leadingHeadingHashtag# Policy Effects`n")
        $null = $allLines.Add("| Category | Policy |$addedTableHeader")
        $null = $allLines.Add("| :------- | :----- |$addedTableDivider")
    }

    $FlatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        $policySetList = $_.policySetList
        $addedEffectColumns = ""
        $effectValue = "Unknown"
        if ($null -ne $_.effectValue) {
            $effectValue = $_.effectValue
        }
        else {
            $effectValue = $_.effectDefault
        }

        if ($effectValue -ne "Manual" -or $IncludeManualPolicies) {
            $groupNamesList = [System.Collections.ArrayList]::new()
            foreach ($item in $ItemList) {
                $shortName = $item.shortName
                if ($policySetList.ContainsKey($shortName)) {
                    $perPolicySet = $policySetList.$shortName
                    $effectValue = $perPolicySet.effectValue
                    $effectAllowedValues = $perPolicySet.effectAllowedValues
                    $text = Convert-EffectToMarkdownString `
                        -Effect $effectValue `
                        -AllowedValues $effectAllowedValues 1 `
                        -inTableBreak $inTableBreak
                    $addedEffectColumns += " $text |"

                    [array] $groupNames = $perPolicySet.groupNames
                    if ($groupNames.Count -gt 0) {
                        $groupNamesList.AddRange($groupNames)
                    }
                }
                else {
                    $addedEffectColumns += "  |"
                }
            }
            $complianceText = ""
            if ($DocumentationSpecification.markdownIncludeComplianceGroupNames) {
                if ($groupNamesList.Count -gt 0) {
                    $groupNamesList = $groupNamesList | Sort-Object -Unique
                    $complianceText = "| $($groupNamesList -join $inTableBreak) "
                }
                else {
                    $complianceText = "| "
                }
            }
            $policyDisplayName = $_.displayName -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
            $policyDescription = $_.description -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
            $null = $allLines.Add("| $($_.category) | **$($policyDisplayName)**$($inTableAfterDisplayNameBreak)$($policyDescription) $complianceText|$addedEffectColumns")
        }
        else {
            Write-Verbose "Skipping manual policy: $($_.name)"
        }
    }
    #endregion Policy Effects

    #region Policy Parameters
    if ($DocumentationSpecification.markdownSuppressParameterSection) {
        Write-Verbose "Suppressing Parameters section in Markdown"
    }
    else {
        $null = $allLines.Add("`n$leadingHeadingHashtag# Policy Parameters by Policy`n")
        $null = $allLines.Add("| Category | Policy |$addedTableHeader")
        $null = $allLines.Add("| :------- | :----- |$addedTableDividerParameters")

        $FlatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
            $policySetList = $_.policySetList
            $addedParametersColumns = ""
            $effectValue = "Unknown"
            if ($null -ne $_.effectValue) {
                $effectValue = $_.effectValue
            }
            else {
                $effectValue = $_.effectDefault
            }

            if ($effectValue -ne "Manual" -or $IncludeManualPolicies) {
                $hasParameters = $false
                foreach ($item in $ItemList) {
                    $shortName = $item.shortName
                    if ($policySetList.ContainsKey($shortName)) {
                        $perPolicySet = $policySetList.$shortName
                        $parameters = $perPolicySet.parameters
                        $text = ""
                        $notFirst = $false
                        foreach ($parameterName in $parameters.Keys) {
                            $parameter = $parameters.$parameterName
                            if (-not $parameter.isEffect) {
                                $hasParameters = $true
                                $markdownMaxParameterLength = 42
                                if ($DocumentationSpecification.markdownMaxParameterLength) {
                                    $markdownMaxParameterLength = $DocumentationSpecification.markdownMaxParameterLength
                                    if ($markdownMaxParameterLength -lt 16) {
                                        Write-Error "markdownMaxParameterLength must be at least 16; it is $markdownMaxParameterLength" -ErrorAction Stop
                                    }
                                }
                                if ($parameterName.length -gt $markdownMaxParameterLength) {
                                    $parameterName = $parameterName.substring(0, $markdownMaxParameterLength - 3) + "..."
                                }
                                $value = $parameter.value
                                if ($notFirst) {
                                    $text += $inTableBreak
                                }
                                else {
                                    $notFirst = $true
                                }
                                if ($null -eq $value) {
                                    $value = $parameter.defaultValue
                                    if ($null -eq $value) {
                                        $value = "null"
                                    }
                                }
                                $valueString = ""
                                if ($value -is [string]) {
                                    $valueString = $value
                                }
                                else {
                                    $valueString = ConvertTo-Json $value -Depth 100 -Compress
                                }
                                if ($valueString.length -gt $markdownMaxParameterLength) {
                                    $valueString = $valueString.substring(0, $markdownMaxParameterLength - 3) + "..."
                                }
                                $text += "$($parameterName) = **``$valueString``**"
                            }
                        }
                        $addedParametersColumns += " $text |"
                    }
                    else {
                        $addedParametersColumns += "  |"
                    }
                }
                if ($hasParameters) {
                    $policyDisplayName = $_.displayName -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
                    $policyDescription = $_.description -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
                    $null = $allLines.Add("| $($_.category) | **$($policyDisplayName)**$($inTableAfterDisplayNameBreak)$($policyDescription) |$addedParametersColumns")
                }
            }
            else {
                Write-Verbose "Skipping manual policy: $($_.name)"
            }
        }
    }
    #endregion Policy Parameters
    
    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$','')/$fileNameStem.md"
    $allLines | Out-File $outputFilePath -Force

    #endregion Markdown

    #region CSV

    $outputEnvironmentColumns = $null -ne $EnvironmentColumnsInCsv -and $EnvironmentColumnsInCsv.Length -gt 0
    if (!$outputEnvironmentColumns) {
        $EnvironmentColumnsInCsv = @( "default" )
    }

    [System.Collections.ArrayList] $allRows = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList] $columnHeaders = [System.Collections.ArrayList]::new()

    # Create header rows for CSV
    $null = $columnHeaders.AddRange(@("name", "referencePath", "policyType", "category", "displayName", "description", "groupNames", "policySets", "allowedEffects" ))
    foreach ($environmentCategory in $EnvironmentColumnsInCsv) {
        $null = $columnHeaders.Add("$($environmentCategory)Effect")
    }
    foreach ($environmentCategory in $EnvironmentColumnsInCsv) {
        $null = $columnHeaders.Add("$($environmentCategory)Parameters")
    }

    # deal with multi value cells
    $inCellSeparator1 = ": "
    $inCellSeparator2 = ","
    $inCellSeparator3 = ","
    if ($WindowsNewLineCells) {
        $inCellSeparator1 = ":`n  "
        $inCellSeparator2 = ",`n  "
        $inCellSeparator3 = ",`n"
    }

    $allRows.Clear()

    # Content rows
    $FlatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # Initialize row - with empty strings
        $rowObj = [ordered]@{}
        foreach ($key in $columnHeaders) {
            $null = $rowObj.Add($key, "")
        }

        # Cache loop values
        $effectAllowedValues = $_.effectAllowedValues
        $isEffectParameterized = $_.isEffectParameterized
        $effectAllowedOverrides = $_.effectAllowedOverrides
        $groupNamesList = $_.groupNamesList
        $effectDefault = $_.effectDefault
        $policySetEffectStrings = $_.policySetEffectStrings

        $effectValue = "Unknown"
        if ($null -ne $_.effectValue) {
            $effectValue = $_.effectValue
        }
        else {
            $effectValue = $_.effectDefault
        }

        if ($effectValue -ne "Manual" -or $IncludeManualPolicies) {

            # Build common columns
            $rowObj.name = $_.name
            $rowObj.referencePath = $_.referencePath
            $rowObj.policyType = $_.policyType
            $rowObj.category = $_.category
            $rowObj.displayName = $_.displayName
            $rowObj.description = $_.description
            if ($groupNamesList.Count -gt 0) {
                $rowObj.groupNames = $groupNamesList -join $inCellSeparator3
            }
            if ($policySetEffectStrings.Count -gt 0) {
                $rowObj.policySets = $policySetEffectStrings -join $inCellSeparator3
            }
            $rowObj.allowedEffects = Convert-AllowedEffectsToCsvString `
                -DefaultEffect $effectDefault `
                -IsEffectParameterized $isEffectParameterized `
                -EffectAllowedValues $effectAllowedValues.Keys `
                -EffectAllowedOverrides $effectAllowedOverrides `
                -InCellSeparator1 $inCellSeparator1 `
                -InCellSeparator2 $inCellSeparator2

            # Per environment columns
            $parameters = $_.parameters
            $parametersValueString = Convert-ParametersToString -Parameters $parameters -OutputType "csvValues"
            $normalizedEffectDefault = Convert-EffectToCsvString -Effect $effectDefault
            foreach ($environmentCategory in $EnvironmentColumnsInCsv) {
                $rowObj["$($environmentCategory)Effect"] = $normalizedEffectDefault
                $rowObj["$($environmentCategory)Parameters"] = $parametersValueString
            }

            # Add row to spreadsheet
            $null = $allRows.Add($rowObj)
        }
        else {
            Write-Verbose "Skipping manual policy: $($_.name)"
        }
    }

    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$','')/$($FileNameStem).csv"
    if ($WindowsNewLineCells) {
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force -Encoding utf8BOM
    }
    else {
        # Mac or Linux
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force -Encoding utf8NoBOM
    }

    #endregion CSV

    #region Compliance CSV

    # Pivot the data by group name
    [hashtable] $perGroupNamePolicies = @{}
    $FlatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        $groupNamesList = $_.groupNamesList
        foreach ($groupName in $groupNamesList) {
            if (!$perGroupNamePolicies.ContainsKey($groupName)) {
                $perGroupNamePolicies.Add($groupName, [System.Collections.ArrayList]::new())
            }
            $null = $perGroupNamePolicies.$groupName.Add($_)
        }
    }

    # Sort by groupName
    $complianceColumnHeaders = @( "groupName", "category", "policyDisplayName", "allowedEffects", "defaultEffect", "policyId" )
    $allRows.Clear()
    $perGroupNamePolicies.Keys | Sort-Object | ForEach-Object -Process {

        # Initialize row in te correct order - with empty strings
        $rowObj = [ordered]@{}
        foreach ($key in $complianceColumnHeaders) {
            $null = $rowObj.Add($key, "")
        }

        # Cache loop values
        $groupName = $_
        $policies = $perGroupNamePolicies.$groupName
        $categoryList = [System.Collections.ArrayList]::new()
        $displayNameList = [System.Collections.ArrayList]::new()
        $effectsList = [System.Collections.ArrayList]::new()
        $defaultEffectList = [System.Collections.ArrayList]::new()
        $policyIdList = [System.Collections.ArrayList]::new()
        foreach ($policy in $policies) {

            # collect Policy information
            $null = $categoryList.Add($policy.category)
            $null = $displayNameList.Add($policy.displayName)
            $null = $policyIdList.Add($policy.name)

            # Collect effects values
            $effectAllowedValues = $policy.effectAllowedValues
            $isEffectParameterized = $policy.isEffectParameterized
            $effectAllowedOverrides = $policy.effectAllowedOverrides
            $effectDefault = $policy.effectDefault
            $allowedEffects = $effectDefault
            if ($isEffectParameterized -and $effectAllowedValues.Count -gt 1) {
                $allowedEffects = "param:$($effectAllowedValues.Keys -join '|')"
            }
            elseif ($effectAllowedOverrides.Count -gt 0) {
                $allowedEffects = "overr:$($effectAllowedOverrides -join '|')"
            }
            $null = $effectsList.Add($allowedEffects)
            $null = $defaultEffectList.Add($effectDefault)
        }

        # Build a row
        $rowObj.groupName = $groupName
        $rowObj.category = $categoryList -join $inCellSeparator3
        $rowObj.policyDisplayName = $displayNameList -join $inCellSeparator3
        $rowObj.allowedEffects = $effectsList -join $inCellSeparator3
        $rowObj.defaultEffect = $defaultEffectList -join $inCellSeparator3
        $rowObj.policyId = $policyIdList -join $inCellSeparator3

        # Add row to spreadsheet
        $null = $allRows.Add($rowObj)
    }

    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$','')/$($FileNameStem)-compliance.csv"
    if ($WindowsNewLineCells) {
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force -Encoding utf8BOM
    }
    else {
        # Mac or Linux
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force -Encoding utf8NoBOM
    }

    #endregion Compliance CSV

    #region Parameters JSON

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.Append("{")
    $null = $sb.Append("`n  `"parameters`": {")
    $FlatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        if ($_.isEffectParameterized) {

            $policySetList = $_.policySetList
            $referencePath = $_.referencePath
            $displayName = $_.displayName
            $category = $_.category

            $null = $sb.Append("`n    // ")
            $null = $sb.Append("`n    // -----------------------------------------------------------------------------------------------------------------------------")
            $null = $sb.Append("`n    // $($category) -- $($displayName)")
            if ($referencePath -ne "") {
                $null = $sb.Append("`n    //     referencePath: $($referencePath)")
            }
            foreach ($item in $ItemList) {
                $shortName = $item.shortName
                if ($policySetList.ContainsKey($shortName)) {
                    $perPolicySet = $policySetList.$shortName
                    $policySetDisplayName = $perPolicySet.displayName
                    if ($perPolicySet.isEffectParameterized) {
                        $null = $sb.Append("`n    //   $($policySetDisplayName): $($perPolicySet.effectDefault) ($($perPolicySet.effectParameterName))")
                    }
                    else {
                        $null = $sb.Append("`n    //   $($policySetDisplayName): $($perPolicySet.effectDefault) ($($perPolicySet.effectReason))")
                    }
                }
            }
            $null = $sb.Append("`n    // -----------------------------------------------------------------------------------------------------------------------------")
            $parameterText = Convert-ParametersToString -Parameters $_.parameters -OutputType "jsonc"
            $null = $sb.Append($parameterText)
        }
    }
    $null = $sb.Append("`n  }")
    $null = $sb.Append("`n}")

    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$', '')/$FileNameStem.jsonc"
    $sb.ToString() | Out-File $outputFilePath -Force

    #endregion

}
