function Out-PolicyAssignmentDocumentationToFile {
    [CmdletBinding()]
    param (
        [string] $OutputPath,
        [switch] $WindowsNewLineCells,
        $DocumentationSpecification,
        [hashtable] $AssignmentsByEnvironment
    )

    [string] $FileNameStem = $DocumentationSpecification.fileNameStem
    [string[]] $environmentCategories = $DocumentationSpecification.environmentCategories
    [string] $Title = $DocumentationSpecification.title

    Write-Information "Generating Policy Assignment documentation for '$Title', files '$FileNameStem'."

    # Checking parameters
    if ($null -eq $FileNameStem -or $FileNameStem -eq "") {
        Write-Error "fileNameStem not specified" -ErrorAction Stop
    }
    if ($null -eq $Title -or $Title -eq "") {
        Write-Error "title not specified" -ErrorAction Stop
    }
    $environmentCategoriesAreValid = $null -ne $environmentCategories -and $environmentCategories.Length -gt 0
    if (-not $environmentCategoriesAreValid) {
        Write-Error "No environmentCategories '$environmentCategories' specified." -ErrorAction Stop
    }

    #region Combine per environment flat lists into a single flat list ($FlatPolicyListAcrossEnvironments)

    $FlatPolicyListAcrossEnvironments = @{}
    foreach ($environmentCategory in $environmentCategories) {
        if (-not $AssignmentsByEnvironment.ContainsKey($environmentCategory)) {
            # Should never happen (programing bug)
            Write-Error "Unknown environmentCategory '$environmentCategory' encountered - bug in EPAC PowerShell code" -ErrorAction Stop
        }

        # Collate Policies
        $perEnvironment = $AssignmentsByEnvironment.$environmentCategory
        $FlatPolicyList = $perEnvironment.flatPolicyList
        foreach ($PolicyTableId in $FlatPolicyList.Keys) {
            $flatPolicyEntry = $FlatPolicyList.$PolicyTableId

            $flatPolicyEntryAcrossEnvironments = @{}
            if ($FlatPolicyListAcrossEnvironments.ContainsKey($PolicyTableId)) {
                $flatPolicyEntryAcrossEnvironments = $FlatPolicyListAcrossEnvironments.$PolicyTableId
                if ($isEffectParameterized) {
                    $flatPolicyEntry.isEffectParameterized = $true
                }
            }
            else {
                $flatPolicyEntryAcrossEnvironments = @{
                    policyTableId          = $PolicyTableId
                    name                   = $flatPolicyEntry.name
                    referencePath          = $flatPolicyEntry.ReferencePath
                    displayName            = $flatPolicyEntry.displayName
                    description            = $flatPolicyEntry.description
                    policyType             = $flatPolicyEntry.policyType
                    category               = $flatPolicyEntry.category
                    isEffectParameterized  = $isEffectParameterized
                    ordinal                = 99
                    effectAllowedValues    = @{}
                    environmentList        = @{}
                    groupNames             = [System.Collections.ArrayList]::new()
                    policySetList          = @{}
                    policySetEffectStrings = $flatPolicyEntry.policySetEffectStrings
                }
                $null = $FlatPolicyListAcrossEnvironments.Add($PolicyTableId, $flatPolicyEntryAcrossEnvironments)
            }

            # Find out lowest ordinal for grouping (optional)
            if ($flatPolicyEntry.ordinal -lt $flatPolicyEntryAcrossEnvironments.ordinal) {
                $flatPolicyEntryAcrossEnvironments.ordinal = $flatPolicyEntry.ordinal
            }

            # Collect union of all effect parameter allowed values
            $EffectAllowedValues = $flatPolicyEntryAcrossEnvironments.effectAllowedValues
            foreach ($allowedValue in $flatPolicyEntry.effectAllowedValues.Keys) {
                if (-not $EffectAllowedValues.ContainsKey($allowedValue)) {
                    $null = $EffectAllowedValues.Add($allowedValue, $allowedValue)
                }
            }

            # Collect union of all group names
            $groupNames = $flatPolicyEntry.groupNames
            if ($null -ne $groupNames -and $groupNames.Count -gt 0) {
                $ExistingGroupNames = $flatPolicyEntryAcrossEnvironments.groupNames
                $ExistingGroupNames.AddRange($groupNames.Keys)
            }

            # Collect environment category specific items
            $environmentList = $flatPolicyEntryAcrossEnvironments.environmentList
            if ($environmentList.ContainsKey($environmentCategory)) {
                Write-Error "Duplicate environmentCategory '$environmentCategory' encountered - bug in EPAC PowerShell code" -ErrorAction Stop
            }
            $EffectValue = "Unknown"
            if ($null -ne $flatPolicyEntry.effectValue) {
                $EffectValue = $flatPolicyEntry.effectValue
            }
            else {
                $EffectValue = $flatPolicyEntry.effectDefault
            }
            $environmentCategoryInfo = @{
                environmentCategory = $environmentCategory
                effectValue         = $EffectValue
                parameters          = $flatPolicyEntry.parameters

                policySetList       = $flatPolicyEntry.policySetList
            }
            $null = $environmentList.Add($environmentCategory, $environmentCategoryInfo)

            # Collect policySet specific items
            $PolicySetList = $flatPolicyEntryAcrossEnvironments.policySetList
            $flatPolicyEntryPolicySetList = $flatPolicyEntry.policySetList
            foreach ($shortName in $flatPolicyEntryPolicySetList.Keys) {
                $PolicySetInfo = $flatPolicyEntryPolicySetList.$shortName
                if (-not $PolicySetList.ContainsKey($shortName)) {
                    $PolicySetEntry = @{
                        shortName             = $shortName
                        id                    = $PolicySetInfo.id
                        name                  = $PolicySetInfo.name
                        displayName           = $PolicySetInfo.displayName
                        description           = $PolicySetInfo.description
                        policyType            = $PolicySetInfo.policyType
                        effectParameterName   = $PolicySetInfo.effectParameterName
                        effectDefault         = $PolicySetInfo.effectDefault
                        effectAllowedValues   = $PolicySetInfo.effectAllowedValues
                        effectReason          = $PolicySetInfo.effectReason
                        isEffectParameterized = $PolicySetInfo.isEffectParameterized
                        parameters            = $PolicySetInfo.parameters
                    }
                    $null = $PolicySetList.Add($shortName, $PolicySetEntry)
                }
            }
        }
    }

    #endregion Combine per environment flat lists into a single flat list ($FlatPolicyListAcrossEnvironments)

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $headerAndToc = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $body = [System.Collections.Generic.List[string]]::new()

    $allLines.Clear()
    $headerAndToc.Clear()
    $body.Clear()

    #region Overview
    $null = $headerAndToc.Add("# $Title $MarkdownOutputType`n")
    $null = $headerAndToc.Add("Auto-generated Policy effect documentation across environments '$($environmentCategories -join "', '")' sorted by Policy category and Policy display name.`n")
    $null = $headerAndToc.Add("## Table of contents`n")

    $null = $headerAndToc.Add("- [Environments](#environments)")
    $null = $body.Add("`n## <a id=`"environments`"></a>Environments`n")
    $addedTableHeader = ""
    $addedTableDivider = ""
    foreach ($environmentCategory in $environmentCategories) {
        $perEnvironment = $AssignmentsByEnvironment.$environmentCategory
        $ItemList = $perEnvironment.itemList
        $AssignmentsDetails = $perEnvironment.assignmentsDetails
        $Scopes = $perEnvironment.scopes
        $null = $body.Add("`n### **$environmentCategory environment**")

        $null = $body.Add("`nScopes`n")
        foreach ($Scope in $Scopes) {
            $null = $body.Add("- $Scope")
        }

        foreach ($item in $ItemList) {
            $AssignmentId = $item.assignmentId
            if ($AssignmentsDetails.ContainsKey($AssignmentId)) {
                # should always be true
                $AssignmentsDetails = $AssignmentsDetails.$AssignmentId
                $null = $body.Add("`nAssignment $($AssignmentsDetails.assignment.displayName)`n")
                $null = $body.Add("- PolicySet: $($AssignmentsDetails.displayName)")
                $null = $body.Add("- Type: $($AssignmentsDetails.policyType)")
                $null = $body.Add("- Category: $($AssignmentsDetails.category)")
                $null = $body.Add("- Description: $($AssignmentsDetails.description)")
            }
        }

        # Calculate environment columns
        $addedTableHeader += " $environmentCategory |"
        $addedTableDivider += " :-----: |"
    }

    #endregion Overview

    $null = $headerAndToc.Add("- [Policy effects across environments](#policy-Effects-across-environment)")
    $null = $body.Add("`n<br/>`n`n## <a id='policy-Effects-across-environment'></a>Policy effects across environment`n`n<br/>`n")
    $null = $body.Add("| Category | Policy |$addedTableHeader")
    $null = $body.Add("| :------- | :----- |$addedTableDivider")

    $FlatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # Build additional columns
        $addedEffectColumns = ""
        $environmentList = $_.environmentList
        $additionalInfoFragment = ""
        foreach ($environmentCategory in $environmentCategories) {
            if ($environmentList.ContainsKey($environmentCategory)) {
                $environmentCategoryValues = $environmentList.$environmentCategory
                $EffectValue = $environmentCategoryValues.effectValue
                $EffectAllowedValues = $_.effectAllowedValues
                $text = Convert-EffectToString `
                    -Effect $EffectValue `
                    -AllowedValues $EffectAllowedValues.Keys `
                    -Markdown
                $addedEffectColumns += " $text |"

                # $Parameters = $environmentCategoryValues.parameters
                # $hasParameters = $false
                # if ($null -ne $Parameters -and $Parameters.psbase.Count -gt 0) {
                #     foreach ($parameterName in $Parameters.Keys) {
                #         $parameter = $Parameters.$parameterName
                #         if (-not $parameter.isEffect) {
                #             $hasParameters = $true
                #             break
                #         }
                #     }
                # }

                # $additionalInfoFragment += "<br/>***$($environmentCategory)*** *environment:*"
                # $PolicySetList = $environmentCategoryValues.policySetList
                # foreach ($shortName in $PolicySetList.Keys) {
                #     $perPolicySet = $PolicySetList.$shortName
                #     # $PolicySetDisplayName = $perPolicySet.displayName
                #     $EffectString = $perPolicySet.effectString
                #     $additionalInfoFragment += "<br/>&nbsp;&nbsp;&nbsp;&nbsp;$($shortName): ``$($EffectString)``"
                # }

                # if ($hasParameters) {
                #     $text = Convert-ParametersToString -Parameters $Parameters -OutputType "markdownAssignment"
                #     $additionalInfoFragment += $text
                # }
            }
            else {
                $addedEffectColumns += " |"
            }

        }
        $groupNames = $_.groupNames
        if ($groupNames.Count -gt 0) {
            $separator = "<br/>&nbsp;&nbsp;&nbsp;&nbsp;"
            $additionalInfoFragment += "<br/>*Compliance:*$separator"
            $sortedGroupNames = $groupNames | Sort-Object -Unique
            $additionalInfoFragment += ($sortedGroupNames -join $separator)
        }
        $null = $body.Add("| $($_.category) | **$($_.displayName)**<br/>$($_.description)$($additionalInfoFragment) | $($addedEffectColumns)")
    }
    $null = $allLines.AddRange($headerAndToc)
    $null = $allLines.AddRange($body)

    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$', '')/$($FileNameStem).md"
    $allLines | Out-File $outputFilePath -Force

    #endregion Markdown

    #region csv

    [System.Collections.ArrayList] $allRows = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList] $columnHeaders = [System.Collections.ArrayList]::new()

    # Create header rows for CSV
    $null = $columnHeaders.AddRange(@("name", "referencePath", "policyType", "category", "displayName", "description", "groupNames", "policySets", "allowedEffects" ))
    foreach ($environmentCategory in $environmentCategories) {
        $null = $columnHeaders.Add("$($environmentCategory)Effect")
    }
    foreach ($environmentCategory in $environmentCategories) {
        $null = $columnHeaders.Add("$($environmentCategory)Parameters")
    }

    # deal with multi value cells
    $inCellSeparator = ","
    if ($WindowsNewLineCells) {
        $inCellSeparator = ",`n"
    }

    $allRows.Clear()

    # Process the table
    $FlatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # Initialize row - with empty strings
        $rowObj = [ordered]@{}
        foreach ($key in $columnHeaders) {
            $null = $rowObj.Add($key, "")
        }

        # Cache loop values
        $EffectAllowedValues = $_.effectAllowedValues
        $groupNames = $_.groupNames
        $PolicySetEffectStrings = $_.policySetEffectStrings

        # Build common columns
        $rowObj.name = $_.name
        $rowObj.referencePath = $_.referencePath
        $rowObj.policyType = $_.policyType
        $rowObj.category = $_.category
        $rowObj.displayName = $_.displayName
        $rowObj.description = $_.description
        $groupNames = $_.groupNames
        if ($groupNames.Count -gt 0) {
            $sortedGroupNameList = $groupNames | Sort-Object -Unique
            $rowObj.groupNames = $sortedGroupNameList -join $inCellSeparator
        }
        if ($PolicySetEffectStrings.Count -gt 0) {
            $rowObj.policySets = $PolicySetEffectStrings -join $inCellSeparator
        }
        if ($EffectAllowedValues.Count -gt 0) {
            $rowObj.allowedEffects = $EffectAllowedValues.Keys -join $inCellSeparator
        }

        $environmentList = $_.environmentList
        # Build environmentCategory columns
        foreach ($environmentCategory in $environmentCategories) {
            if ($environmentList.ContainsKey($environmentCategory)) {
                $perEnvironment = $environmentList.$environmentCategory
                if ($null -ne $perEnvironment.effectValue) {
                    $rowObj["$($environmentCategory)Effect"] = $perEnvironment.effectValue
                }
                else {
                    $rowObj["$($environmentCategory)Effect"] = $_.effectDefault
                }

                $text = Convert-ParametersToString -Parameters $perEnvironment.parameters -OutputType "csvValues"
                $rowObj["$($environmentCategory)Parameters"] = $text
            }
        }

        # Add row to spreadsheet
        $null = $allRows.Add($rowObj)
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

    #endregion csv

}
