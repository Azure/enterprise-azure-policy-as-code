function Out-PolicyAssignmentDocumentationToFile {
    [CmdletBinding()]
    param (
        [string] $OutputPath,
        [switch] $WindowsNewLineCells,
        $DocumentationSpecification,
        [hashtable] $AssignmentsByEnvironment,
        [switch] $IncludeManualPolicies
    )

    [string] $fileNameStem = $DocumentationSpecification.fileNameStem
    [string[]] $environmentCategories = $DocumentationSpecification.environmentCategories
    [string] $title = $DocumentationSpecification.title

    Write-Information "Generating Policy Assignment documentation for '$title', files '$fileNameStem'."

    # Checking parameters
    if ($null -eq $fileNameStem -or $fileNameStem -eq "") {
        Write-Error "fileNameStem not specified" -ErrorAction Stop
    }
    if ($null -eq $title -or $title -eq "") {
        Write-Error "title not specified" -ErrorAction Stop
    }
    $environmentCategoriesAreValid = $null -ne $environmentCategories -and $environmentCategories.Length -gt 0
    if (-not $environmentCategoriesAreValid) {
        Write-Error "No environmentCategories '$environmentCategories' specified." -ErrorAction Stop
    }

    #region Combine per environment flat lists into a single flat list ($flatPolicyListAcrossEnvironments)

    $flatPolicyListAcrossEnvironments = @{}
    foreach ($environmentCategory in $environmentCategories) {
        if (-not $AssignmentsByEnvironment.ContainsKey($environmentCategory)) {
            # Should never happen (programing bug)
            Write-Error "Unknown environmentCategory '$environmentCategory' encountered - bug in EPAC PowerShell code" -ErrorAction Stop
        }

        # Collate Policies
        $perEnvironment = $AssignmentsByEnvironment.$environmentCategory
        $flatPolicyList = $perEnvironment.flatPolicyList
        foreach ($policyTableId in $flatPolicyList.Keys) {

            $flatPolicyEntry = $flatPolicyList.$policyTableId
            $isEffectParameterized = $flatPolicyEntry.isEffectParameterized
            $effectValue = "Unknown"
            if ($null -ne $flatPolicyEntry.effectValue) {
                $effectValue = $flatPolicyEntry.effectValue
            }
            else {
                $effectValue = $flatPolicyEntry.effectDefault
            }

            if ($effectValue -ne "Manual" -or $IncludeManualPolicies) {

                $flatPolicyEntryAcrossEnvironments = @{}
                if ($flatPolicyListAcrossEnvironments.ContainsKey($policyTableId)) {
                    $flatPolicyEntryAcrossEnvironments = $flatPolicyListAcrossEnvironments.$policyTableId
                    if ($isEffectParameterized) {
                        $flatPolicyEntry.isEffectParameterized = $true
                    }
                }
                else {
                    $flatPolicyEntryAcrossEnvironments = @{
                        policyTableId          = $policyTableId
                        name                   = $flatPolicyEntry.name
                        referencePath          = $flatPolicyEntry.ReferencePath
                        displayName            = $flatPolicyEntry.displayName
                        description            = $flatPolicyEntry.description
                        policyType             = $flatPolicyEntry.policyType
                        category               = $flatPolicyEntry.category
                        isEffectParameterized  = $isEffectParameterized
                        ordinal                = 99
                        effectAllowedValues    = @{}
                        effectAllowedOverrides = $flatPolicyEntry.effectAllowedOverrides
                        environmentList        = @{}
                        groupNames             = [System.Collections.ArrayList]::new()
                        policySetList          = @{}
                        policySetEffectStrings = $flatPolicyEntry.policySetEffectStrings
                    }
                    $null = $flatPolicyListAcrossEnvironments.Add($policyTableId, $flatPolicyEntryAcrossEnvironments)
                }

                # Find out lowest ordinal for grouping (optional)
                if ($flatPolicyEntry.ordinal -lt $flatPolicyEntryAcrossEnvironments.ordinal) {
                    $flatPolicyEntryAcrossEnvironments.ordinal = $flatPolicyEntry.ordinal
                }

                # Collect union of all effect parameter allowed values
                $effectAllowedValues = $flatPolicyEntryAcrossEnvironments.effectAllowedValues
                foreach ($allowedValue in $flatPolicyEntry.effectAllowedValues.Keys) {
                    if (-not $effectAllowedValues.ContainsKey($allowedValue)) {
                        $null = $effectAllowedValues.Add($allowedValue, $allowedValue)
                    }
                }

                # Collect union of all group names
                $groupNamesList = $flatPolicyEntry.groupNamesList
                if ($null -ne $groupNamesList -and $groupNamesList.Count -gt 0) {
                    $existingGroupNames = $flatPolicyEntryAcrossEnvironments.groupNames
                    $existingGroupNames.AddRange($groupNamesList)
                }

                # Collect environment category specific items
                $environmentList = $flatPolicyEntryAcrossEnvironments.environmentList
                if ($environmentList.ContainsKey($environmentCategory)) {
                    Write-Error "Duplicate environmentCategory '$environmentCategory' encountered - bug in EPAC PowerShell code" -ErrorAction Stop
                }
                $environmentCategoryInfo = @{
                    environmentCategory = $environmentCategory
                    effectValue         = $effectValue
                    parameters          = $flatPolicyEntry.parameters

                    policySetList       = $flatPolicyEntry.policySetList
                }
                $null = $environmentList.Add($environmentCategory, $environmentCategoryInfo)

                # Collect policySet specific items
                $policySetList = $flatPolicyEntryAcrossEnvironments.policySetList
                $flatPolicyEntryPolicySetList = $flatPolicyEntry.policySetList
                foreach ($shortName in $flatPolicyEntryPolicySetList.Keys) {
                    $policySetInfo = $flatPolicyEntryPolicySetList.$shortName
                    if (-not $policySetList.ContainsKey($shortName)) {
                        $policySetEntry = @{
                            shortName              = $shortName
                            id                     = $policySetInfo.id
                            name                   = $policySetInfo.name
                            displayName            = $policySetInfo.displayName
                            description            = $policySetInfo.description
                            policyType             = $policySetInfo.policyType
                            effectParameterName    = $policySetInfo.effectParameterName
                            effectDefault          = $policySetInfo.effectDefault
                            effectAllowedValues    = $policySetInfo.effectAllowedValues
                            effectAllowedOverrides = $policySetInfo.effectAllowedOverrides
                            effectReason           = $policySetInfo.effectReason
                            isEffectParameterized  = $policySetInfo.isEffectParameterized
                            parameters             = $policySetInfo.parameters
                        }
                        $null = $policySetList.Add($shortName, $policySetEntry)
                    }
                }
            }
            else {
                Write-Verbose "Skipping Manual effect Policy '$($flatPolicyEntry.displayName)'"
            }
        }
    }

    #endregion Combine per environment flat lists into a single flat list ($flatPolicyListAcrossEnvironments)

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    $null = $allLines.Add("# $title`n")
    $null = $allLines.Add("Auto-generated Policy effect documentation across environments '$($environmentCategories -join "', '")' sorted by Policy category and Policy display name.`n")
    $null = $allLines.Add("## Table of Contents`n")
    $null = $allLines.Add("- [Policy Effects](#policy-effects)")

    #region Policy Effects

    $addedTableHeader = ""
    $addedTableDivider = ""
    foreach ($environmentCategory in $environmentCategories) {
        $null = $allLines.Add("- [Environment Category ``$environmentCategory``](#environment-category-$($environmentCategory.ToLower()))")
        # Calculate environment columns
        $addedTableHeader += " $environmentCategory |"
        $addedTableDivider += " :-----: |"
    }
    $null = $allLines.Add("`n## Policy Effects`n")
    $null = $allLines.Add("| Category | Policy |$addedTableHeader")
    $null = $allLines.Add("| :------- | :----- |$addedTableDivider")

    $flatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # Build additional columns
        $addedEffectColumns = ""
        $environmentList = $_.environmentList
        $additionalInfoFragment = ""
        foreach ($environmentCategory in $environmentCategories) {
            if ($environmentList.ContainsKey($environmentCategory)) {
                $environmentCategoryValues = $environmentList.$environmentCategory
                $effectValue = $environmentCategoryValues.effectValue
                $effectAllowedValues = $_.effectAllowedValues
                $text = Convert-EffectToMarkdownString `
                    -Effect $effectValue `
                    -AllowedValues $effectAllowedValues.Keys
                $addedEffectColumns += " $text |"

                # $parameters = $environmentCategoryValues.parameters
                # $hasParameters = $false
                # if ($null -ne $parameters -and $parameters.psbase.Count -gt 0) {
                #     foreach ($parameterName in $parameters.Keys) {
                #         $parameter = $parameters.$parameterName
                #         if (-not $parameter.isEffect) {
                #             $hasParameters = $true
                #             break
                #         }
                #     }
                # }

                # $additionalInfoFragment += "<br/>***$($environmentCategory)*** *environment:*"
                # $policySetList = $environmentCategoryValues.policySetList
                # foreach ($shortName in $policySetList.Keys) {
                #     $perPolicySet = $policySetList.$shortName
                #     # $policySetDisplayName = $perPolicySet.displayName
                #     $effectString = $perPolicySet.effectString
                #     $additionalInfoFragment += "<br/>&nbsp;&nbsp;&nbsp;&nbsp;$($shortName): ``$($effectString)``"
                # }

                # if ($hasParameters) {
                #     $text = Convert-ParametersToString -Parameters $parameters -OutputType "markdownAssignment"
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
        $null = $allLines.Add("| $($_.category) | **$($_.displayName)**<br/>$($_.description)$($additionalInfoFragment) | $($addedEffectColumns)")
    }

    #endregion Policy Effects

    #region Environment Categories

    foreach ($environmentCategory in $environmentCategories) {
        $perEnvironment = $AssignmentsByEnvironment.$environmentCategory
        $itemList = $perEnvironment.itemList
        $assignmentsDetails = $perEnvironment.assignmentsDetails
        $scopes = $perEnvironment.scopes
        $null = $allLines.Add("`n## Environment Category ``$environmentCategory``")

        $null = $allLines.Add("`n### Scopes`n")
        foreach ($scope in $scopes) {
            $null = $allLines.Add("- $scope")
        }

        foreach ($item in $itemList) {
            $assignmentId = $item.assignmentId
            if ($assignmentsDetails.ContainsKey($assignmentId)) {
                # should always be true
                $assignmentsDetail = $assignmentsDetails.$assignmentId
                $null = $allLines.Add("`n### Assignment: ``$($assignmentsDetail.assignment.properties.displayName)```n")
                $null = $allLines.Add("| Property | Value |")
                $null = $allLines.Add("| :------- | :---- |")
                $null = $allLines.Add("| Assignment Id | $($assignmentId) |")
                $null = $allLines.Add("| Policy Set | ``$($assignmentsDetail.displayName)`` |")
                $null = $allLines.Add("| Policy Set Id | $($assignmentsDetail.policySetId) |")
                $null = $allLines.Add("| Type | $($assignmentsDetail.policyType) |")
                $null = $allLines.Add("| Category | ``$($assignmentsDetail.category)`` |")
                $null = $allLines.Add("| Description | $($assignmentsDetail.description) |")
            }
        }
    }

    #endregion Environment Categories

    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$', '')/$($fileNameStem).md"
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
    $inCellSeparator1 = ": "
    $inCellSeparator2 = ","
    $inCellSeparator3 = ","
    if ($WindowsNewLineCells) {
        $inCellSeparator1 = ":`n  "
        $inCellSeparator2 = ",`n  "
        $inCellSeparator3 = ",`n"
    }


    $allRows.Clear()

    # Process the table
    $flatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # Initialize row - with empty strings
        $rowObj = [ordered]@{}
        foreach ($key in $columnHeaders) {
            $null = $rowObj.Add($key, "")
        }

        # Cache loop values
        # $effectAllowedValues = $_.effectAllowedValues
        # $groupNames = $_.groupNames
        # $policySetEffectStrings = $_.policySetEffectStrings
        $effectAllowedValues = $_.effectAllowedValues
        $isEffectParameterized = $_.isEffectParameterized
        $effectAllowedOverrides = $_.effectAllowedOverrides
        $groupNames = $_.groupNames
        $effectDefault = $_.effectDefault
        $policySetEffectStrings = $_.policySetEffectStrings

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
            $rowObj.groupNames = $sortedGroupNameList -join $inCellSeparator3
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

        $environmentList = $_.environmentList
        # Build environmentCategory columns
        foreach ($environmentCategory in $environmentCategories) {
            if ($environmentList.ContainsKey($environmentCategory)) {
                $perEnvironment = $environmentList.$environmentCategory
                if ($null -ne $perEnvironment.effectValue) {
                    $rowObj["$($environmentCategory)Effect"] = Convert-EffectToCsvString $perEnvironment.effectValue
                }
                else {
                    $rowObj["$($environmentCategory)Effect"] = Convert-EffectToCsvString $_.effectDefault
                }

                $text = Convert-ParametersToString -Parameters $perEnvironment.parameters -OutputType "csvValues"
                $rowObj["$($environmentCategory)Parameters"] = $text
            }
        }

        # Add row to spreadsheet
        $null = $allRows.Add($rowObj)
    }

    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$','')/$($fileNameStem).csv"
    if ($WindowsNewLineCells) {
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force -Encoding utf8BOM
    }
    else {
        # Mac or Linux
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force -Encoding utf8NoBOM
    }

    #endregion csv

}
