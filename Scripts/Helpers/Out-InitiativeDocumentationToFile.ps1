#Requires -PSEdition Core

function Out-InitiativeDocumentationToFile {
    [CmdletBinding()]
    param (
        [string] $outputPath,
        [string] $fileNameStem,
        [string] $pacEnvironmentSelector,
        [string] $title,
        [array] $initiatives,
        [hashtable] $policyInitiativeInfo
    )

    Write-Information "Generating '$title' documentation files '$fileNameStem'."

    #region Collate

    [hashtable] $flatPolicyList = @{}
    foreach ($initiative in $initiatives) {
        $shortName = $initiative.shortName
        if (-not $shortName) {
            Write-Error "'$title' initiatives array entry does not specify an Initiative shortName." -ErrorAction Stop
        }
        $initiativeId = $initiative.id
        if (-not $initiativeId) {
            Write-Error "'$title' initiatives array entry does not specify an Initiative id." -ErrorAction Stop
        }
        $initiativeInfos = $policyInitiativeInfo.initiativeInfos
        if (-not $initiativeInfos.ContainsKey($initiativeId)) {
            Write-Error "'$title' initiative does not exist: $initiativeId." -ErrorAction Stop
        }

        # Collate
        $initiativeInfo = $initiativeInfos.$initiativeId
        foreach ($policyDefinition in $initiativeInfo.policyDefinitions) {
            $policyId = $policyDefinition.id
            [hashtable] $policyFlatEntry = @{}
            if ($flatPolicyList.ContainsKey($policyId)) {
                $policyFlatEntry = $flatPolicyList.$policyId
            }
            else {
                $policyFlatEntry = @{
                    name           = $policyDefinition.name
                    displayName    = $policyDefinition.displayName
                    description    = $policyDefinition.description
                    policyType     = $policyDefinition.policyType
                    category       = $policyDefinition.category
                    initiativeList = @{}
                }
                $null = $flatPolicyList.Add($policyId, $policyFlatEntry)
            }
            $effectReason = $policyDefinition.effectReason
            $isEffectParameterized = $effectReason -ne "PolicyFixed" -and $effectReason -ne "InitiativeFixed" -and $effectReason -ne "PolicyDefault"

            $perInitiative = @{
                initiativeDisplayName       = $initiativeInfo.displayName
                effectParameterName         = $policyDefinition.effectParameterName
                effectValue                 = $policyDefinition.effectValue
                effectDefault               = $policyDefinition.effectDefault
                effectAllowedValues         = $policyDefinition.effectAllowedValues
                effectReason                = $effectReason
                isEffectParameterized       = $isEffectParameterized
                parameters                  = $policyDefinition.parameters
                policyDefinitionReferenceId = $policyDefinition.policyDefinitionReferenceId
                groupNames                  = $policyDefinition.groupNames
            }
            $initiativeList = $policyFlatEntry.initiativeList
            if (-not $initiativeList.ContainsKey($shortName)) {
                $initiativeList.Add($shortName, $perInitiative)
            }
            else {
                Write-Error "'$title' initiatives array entry contains duplicate shortName ($shortName)." -ErrorAction Stop
            }
        }

    }

    #endregion

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $headerAndToc = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $body = [System.Collections.Generic.List[string]]::new()

    $null = $headerAndToc.Add("# $title`n")
    $null = $headerAndToc.Add("Auto-generaed Policy effect documentation for environment '$($environmentCategory)' grouped by Effect and sorted by Policy category and Policy display name.`n")
    $null = $headerAndToc.Add("## Table of contents`n")

    $null = $headerAndToc.Add("- [Initiatives](#initiatives)")
    $null = $body.Add("`n## <a id=`"initiatives`"></a>Initiatives`n")
    $addedTableHeader = ""
    $addedTableDivider = ""
    foreach ($initiative in $initiatives) {
        $shortName = $initiative.shortName
        $initiativeId = $initiative.id
        $initiativeInfos = $policyInitiativeInfo.initiativeInfos
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
        $addedEffectParameterNameRows = ""
        foreach ($initiative in $initiatives) {
            $shortName = $initiative.shortName
            if ($initiativeList.ContainsKey($shortName)) {
                $perInitiative = $initiativeList.$shortName
                $effectParameterName = $perInitiative.effectParameterName
                $effectValue = $perInitiative.effectValue
                $effectAllowedValues = $perInitiative.effectAllowedValues
                $isEffectParameterized = $perInitiative.isEffectParameterized
                $text = Convert-EffectToString `
                    -effect $effectValue `
                    -allowedValues $effectAllowedValues `
                    -isParameterized $isEffectParameterized `
                    -Markdown
                $addedEffectColumns += " $text |"

                if ($isParameterized) {
                    $addedEffectParameterNameRows += "<br/>*$($shortName): $effectParameterName*"
                }
            }
            $addedEffectColumns += "  |"
        }
        $null = $body.Add("| $($_.category) | **$($_.displayName)**<br/>$($_.description)$($addedEffectParameterNameRows) |$addedEffectColumns")
    }
    $null = $headerAndToc.Add("`n<br/>")
    $null = $allLines.AddRange($headerAndToc)
    $null = $allLines.AddRange($body)

    # Output file
    $outputFilePath = "$($outputPath -replace '[/\\]$','')/$fileNameStem.md"
    $allLines | Out-File $outputFilePath -Force

    #endregion Markdown

    #region csv

    [System.Collections.ArrayList] $cells = [System.Collections.ArrayList]::new()
    $allLines.Clear()

    # Create header row
    $null = $cells.AddRange(@("Category", "Policy", "Description"))
    foreach ($initiative in $initiatives) {
        $shortName = $initiative.shortName
        $null = $cells.Add($shortName)
    }
    foreach ($initiative in $initiatives) {
        $shortName = $initiative.shortName
        $null = $cells.Add("$shortName Parameters")
        $null = $cells.Add("Groups")
    }
    $headerString = Convert-ListToToCsvRow($cells)
    $null = $allLines.Add($headerString)

    $flatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {

        # Build common columns
        $cells.Clear()
        $category = $_.category
        $displayName = $_.displayName
        $description = $_.description
        $null = $cells.AddRange(@($category, $displayName, $description))

        $initiativeList = $_.initiativeList
        foreach ($initiative in $initiatives) {
            $shortName = $initiative.shortName
            if ($initiativeList.ContainsKey($shortName)) {
                $perInitiative = $initiativeList.$shortName
                $effectValue = $perInitiative.effectValue
                $effectAllowedValues = $perInitiative.effectAllowedValues
                $isEffectParameterized = $perInitiative.isEffectParameterized
                $text = Convert-EffectToString `
                    -effect $effectValue `
                    -allowedValues $effectAllowedValues `
                    -isParameterized $isEffectParameterized
                $null = $cells.Add($text)
            }
            else {
                $null = $cells.Add("n/a")
            }

        }

        # Build details by Initiave columns
        foreach ($initiative in $initiatives) {
            $shortName = $initiative.shortName
            if ($initiativeList.ContainsKey($shortName)) {
                $perInitiative = $initiativeList.$shortName

                # Parameters cell
                $parameters = $perInitiative.parameters
                $text = Convert-ParametersToString `
                    -parameters $parameters
                $null = $cells.Add($text)

                # Group Names cell
                $groupNames = $perInitiative.groupNames
                $groupNamesFragment = "n/a"
                if ($groupNames.Count -gt 0) {
                    $groupNamesFragment = $groupNames -join "\n"
                }
                $null = $cells.Add($groupNamesFragment)
            }
            else {
                $null = $cells.Add("n/a")
                $null = $cells.Add("n/a")
            }
        }
        $row = Convert-ListToToCsvRow($cells)
        $null = $allLines.Add($row)
    }

    # Output file
    $outputFilePath = "$($outputPath -replace '[/\\]$','')/$fileNameStem.csv"
    $allLines | Out-File $outputFilePath -Force

    #endregion csv


    #region Parameters Json

    $sb = [System.Text.StringBuilder]::new()
    [void] $sb.Append("{")
    [void] $sb.Append("`n  `"parameters`": {")
    [hashtable] $parametersAlreadyCovered = @{}
    $flatPolicyList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        $initiativeList = $_.initiativeList

        [void] $sb.Append("`n    // ")
        [void] $sb.Append("`n    // -----------------------------------------------------------------------------------------------------------------------------")
        [void] $sb.Append("`n    // '$($_.category)' Policy: '$($_.displayName)'")
        [void] $sb.Append("`n    // -----------------------------------------------------------------------------------------------------------------------------")

        $parametersForThisPolicy = @{}
        foreach ($initiative in $initiatives) {
            $shortName = $initiative.shortName
            if ($initiativeList.ContainsKey($shortName)) {
                $perInitiative = $initiativeList.$shortName
                $initiativeDisplayName = $perInitiative.initiativeDisplayName
                $parameters = $perInitiative.parameters
                foreach ($parameterName in $parameters.Keys) {
                    $parameter = $parameters.$parameterName
                    if ($parametersForThisPolicy.ContainsKey($parameterName)) {
                        $parameterForThisPolicy = $parametersForThisPolicy.$parameterName
                        $initiativesForThisParameter = $parameterForThisPolicy.initiativesForThisParameter
                        $initiativeText = ""
                        if ($perInitiative.isEffectParameterized) {
                            $initiativeText = "'$($initiativeDisplayName)':       effect default) = $($perInitiative.effectDefault)"
                        }
                        else {
                            $initiativeText = "'$($initiativeDisplayName)':       effect fixed = $($perInitiative.effectValue)"
                        }
                        $null = $initiativesForThisParameter.Add("$initiativeText")
                    }
                    else {
                        $noDefault = $false
                        $value = $parameter.value
                        if ($null -eq $value) {
                            if ($parameter.defaultValue) {
                                $value = $parameter.defaultValue
                            }
                            else {
                                $noDefault = $true
                                $value = "undefined"
                            }
                        }
                        $parameterValueString = ConvertTo-Json $value -Depth 100 -Compress
                        $parameterString = "`"$parameterName`": $($parameterValueString)"

                        $allowedValuesString = "n/a"
                        if ($parameter.allowedValues) {
                            $allowedValuesString = $parameter.allowedValues | ConvertTo-Json -Depth 100 -Compress
                        }

                        $initiativesForThisParameter = [System.Collections.ArrayList]::new()
                        $initiativeText = ""
                        if ($perInitiative.isEffectParameterized) {
                            $initiativeText = "'$($initiativeDisplayName)':       effect default = $($perInitiative.effectDefault)"
                        }
                        else {
                            $initiativeText = "'$($initiativeDisplayName)':       effect fixed = $($perInitiative.effectValue)"
                        }
                        $null = $initiativesForThisParameter.Add("$initiativeText")
                        $parameterForThisPolicy = @{
                            parameterString             = $parameterString
                            noDefault                   = $noDefault
                            allowedValuesString         = $allowedValuesString
                            initiativesForThisParameter = $initiativesForThisParameter
                        }
                        $null = $parametersForThisPolicy.Add($parameterName, $parameterForThisPolicy)
                    }
                }
            }
        }
        if ($parametersForThisPolicy.Count -gt 0) {
            foreach ($parameterName in $parametersForThisPolicy.Keys) {
                $parameterForThisPolicy = $parametersForThisPolicy.$parameterName
                $noDefault = $parameterForThisPolicy.noDefault
                if ($parametersAlreadyCovered.ContainsKey($parameterName)) {
                    [void] $sb.Append("`n    // Duplicate:  $($parameterForThisPolicy.parameterString),")
                }
                elseif ($noDefault) {
                    [void] $sb.Append("`n    // No Default: $($parameterForThisPolicy.parameterString),")
                }
                else {
                    [void] $sb.Append("`n    $($parameterForThisPolicy.parameterString),")
                    $null = $parametersAlreadyCovered.Add($parameterName, "covered")
                }
                [void] $sb.Append("`n    //    Alowed Values = $($parameterForThisPolicy.allowedValuesString)")
                $initiativesForThisParameter = $parameterForThisPolicy.initiativesForThisParameter
                foreach ($initiativeForThisParameter in $initiativesForThisParameter) {
                    [void] $sb.Append("`n    //    $($initiativeForThisParameter)")
                }
            }
        }
        else {
            foreach ($initiative in $initiatives) {
                $shortName = $initiative.shortName
                if ($initiativeList.ContainsKey($shortName)) {
                    $perInitiative = $initiativeList.$shortName
                    $initiativeDisplayName = $perInitiative.initiativeDisplayName
                    $initiativeText = ""
                    if ($perInitiative.isEffectParameterized) {
                        $initiativeText = "'$($initiativeDisplayName)':       effect default = $($perInitiative.effectDefault)"
                    }
                    else {
                        $initiativeText = "'$($initiativeDisplayName)':       effect fixed = $($perInitiative.effectValue)"
                    }
                    [void] $sb.Append("`n    //    $($initiativeText)")
                }
            }
        }
    }
    [void] $sb.Append("`n  }")
    [void] $sb.Append("`n}")

    # Output file
    $outputFilePath = "$($outputPath -replace '[/\\]$', '')/$fileNameStem.jsonc"
    $sb.ToString() | Out-File $outputFilePath -Force

    #endregion

}
