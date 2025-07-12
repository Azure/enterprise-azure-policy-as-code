function Out-DocumentationForPolicyAssignments {
    [CmdletBinding()]
    param (
        [string] $OutputPath,
        [string] $OutputPathServices,
        [switch] $WindowsNewLineCells,
        $DocumentationSpecification,
        [hashtable] $AssignmentsByEnvironment,
        [switch] $IncludeManualPolicies,
        [hashtable] $PacEnvironments,
        [string] $WikiClonePat
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
            # Should never happen (programming bug)
            Write-Error "Unknown environmentCategory '$environmentCategory' encountered - bug in EPAC PowerShell code" -ErrorAction Stop
        }

        # Collate Policies
        $perEnvironment = $AssignmentsByEnvironment.$environmentCategory
        $flatPolicyList = $perEnvironment.flatPolicyList
        foreach ($policyTableId in $flatPolicyList.Keys) {

            $flatPolicyEntry = $flatPolicyList.$policyTableId
            $isEffectParameterized = $flatPolicyEntry.isEffectParameterized
            $policyDisplayName = $flatPolicyEntry.displayName -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
            $policyDescription = $flatPolicyEntry.description -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
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
                        displayName            = $policyDisplayName
                        description            = $policyDescription
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
                        isReferencePathMatch   = $false
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
                        $policySetDisplayName = $policySetInfo.displayName -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
                        $policySetDescription = $policySetInfo.description -replace "\n\r", " " -replace "\n", " " -replace "\r", " "
                        $policySetEntry = @{
                            shortName              = $shortName
                            id                     = $policySetInfo.id
                            name                   = $policySetInfo.name
                            displayName            = $policySetDisplayName
                            description            = $policySetDescription
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

    #region Process Deprecated
    $deprecatedHash = @{}
    foreach ($key in $policyResourceDetails.policies.keys) {
        if ($true -eq $policyResourceDetails.policies.$key.isDeprecated) {
            $deprecatedHash[$policyResourceDetails.policies.$key.name] = $policyResourceDetails.policies.$key
        }
    }
    #region Review Duplicates

    # Iterate over each key-value pair in the hashtable
    foreach ($policyDef in $flatPolicyListAcrossEnvironments.Keys) {
        # Skip if policy is BuiltIn
        if ($flatPolicyListAcrossEnvironments[$policyDef].policyType -ne "BuiltIn") {
            # Compare the current key's value with every other key's value
            foreach ($policyDefCompare in $flatPolicyListAcrossEnvironments.Keys) {
                # Skip the comparison if it's the same key or the compare def is a BuiltIn
                if ($policyDef -ne $policyDefCompare -and $flatPolicyListAcrossEnvironments[$policyDefCompare].policyType -ne "BuiltIn") {
                    # Check if already been tagged as a match to another referencePathId
                    if ($flatPolicyListAcrossEnvironments[$policyDef].isReferencePathMatch -eq $false) {
                        # Check if the referencePath values match
                        if ($flatPolicyListAcrossEnvironments[$policyDef].referencePath -eq $flatPolicyListAcrossEnvironments[$policyDefCompare].referencePath) {
                            # Check if the Policy Assignment Display Name values match
                            if ($flatPolicyListAcrossEnvironments[$policyDef].displayName -eq $flatPolicyListAcrossEnvironments[$policyDefCompare].displayName) {
                                # Set variable for isReferencePatMatch to true
                                $flatPolicyListAcrossEnvironments[$policyDefCompare].isReferencePathMatch = $true
                                # Find which env category is missing, add it to $policyDef
                                foreach ($env in $flatPolicyListAcrossEnvironments[$policyDefCompare].environmentList.keys) {
                                    if (-not $flatPolicyListAcrossEnvironments[$policyDef].environmentList.ContainsKey($env)) {
                                        # Copy environment from match to original key
                                        $flatPolicyListAcrossEnvironments[$policyDef].environmentList[$env] = $flatPolicyListAcrossEnvironments[$policyDefCompare].environmentList[$env]
                                    }
                                }
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    #endregion Combine per environment flat lists into a single flat list ($flatPolicyListAcrossEnvironments)

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $assignmentsByCategoryHeader = [System.Collections.Generic.List[string]]::new()
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
    $null = $allLines.Add("Auto-generated Policy effect documentation across environments '$($environmentCategories -join "', '")' sorted by Policy category and Policy display name.")

    $inTableAfterDisplayNameBreak = "<br/>"
    $inTableBreak = "<br/>"
    if ($DocumentationSpecification.markdownNoEmbeddedHtml) {
        $inTableAfterDisplayNameBreak = ": "
        $inTableBreak = ", "
    }



    #region Environment Categories

    foreach ($environmentCategory in $environmentCategories) {
        $perEnvironment = $AssignmentsByEnvironment.$environmentCategory
        $itemList = $perEnvironment.itemList
        $assignmentsDetails = $perEnvironment.assignmentsDetails
        $scopes = $perEnvironment.scopes
        $null = $allLines.Add("`n$leadingHeadingHashtag# Environment Category ``$environmentCategory``")

        $null = $allLines.Add("`n$leadingHeadingHashtag## Scopes`n")
        foreach ($scope in $scopes) {
            $null = $allLines.Add("- $scope")
        }

        foreach ($item in $itemList) {
            $assignmentId = $item.assignmentId
            if ($assignmentsDetails.ContainsKey($assignmentId)) {
                $assignmentsDetail = $assignmentsDetails.$assignmentId
                if ($assignmentsDetail.policySetId) {
                    $null = $allLines.Add("`n$leadingHeadingHashtag## Assignment: ``$($assignmentsDetail.assignment.properties.displayName)```n")
                    $null = $allLines.Add("| Property | Value |")
                    $null = $allLines.Add("| :------- | :---- |")
                    $null = $allLines.Add("| Assignment Id | $($assignmentId) |")
                    $null = $allLines.Add("| Policy Set | ``$($assignmentsDetail.displayName)`` |")
                    $null = $allLines.Add("| Policy Set Id | $($assignmentsDetail.policySetId) |")
                    $null = $allLines.Add("| Type | $($assignmentsDetail.policyType) |")
                    $null = $allLines.Add("| Category | ``$($assignmentsDetail.category)`` |")
                    $null = $allLines.Add("| Description | $($assignmentsDetail.description) |")  
                }
                if (!$assignmentsDetail.policySetId -and $assignmentsDetail.policyDefinitionId) {
                    $null = $allLines.Add("`n$leadingHeadingHashtag## Assignment: ``$($assignmentsDetail.assignment.properties.displayName)```n")
                    $null = $allLines.Add("| Property | Value |")
                    $null = $allLines.Add("| :------- | :---- |")
                    $null = $allLines.Add("| Assignment Id | $($assignmentId) |")
                    $null = $allLines.Add("| Policy | ``$($assignmentsDetail.displayName)`` |")
                    $null = $allLines.Add("| Policy Definition Id | $($assignmentsDetail.policyDefinitionId) |")
                    $null = $allLines.Add("| Type | $($assignmentsDetail.policyType) |")
                    $null = $allLines.Add("| Category | ``$($assignmentsDetail.category)`` |")
                    $null = $allLines.Add("| Description | $($assignmentsDetail.description) |")  
                }
            }
        }
    }

    #endregion Environment Categories

    #region Policy Effects

    # Initialize Hashtable to hold sub pages
    $assignmentsByCategory = @{}

    $addedTableHeader = ""
    $addedTableDivider = ""
    $addedTableDividerParameters = ""
    foreach ($environmentCategory in $environmentCategories) {
        # Calculate environment columns
        $addedTableHeader += " $environmentCategory |"
        $addedTableDivider += " :-----: |"
        $addedTableDividerParameters += " :----- |"
    }

    if ($DocumentationSpecification.markdownIncludeComplianceGroupNames) {
        $null = $allLines.Add("`n$leadingHeadingHashtag# Policy Effects by Policy`n")
        $null = $allLines.Add("| Category | Policy | Group Names |$addedTableHeader")
        $null = $allLines.Add("| :------- | :----- | :---------- |$addedTableDivider")
        $null = $assignmentsByCategoryHeader.Add("`n$leadingHeadingHashtag# Policy Effects by Policy`n")
        $null = $assignmentsByCategoryHeader.Add("| Category | Policy | Group Names |$addedTableHeader")
        $null = $assignmentsByCategoryHeader.Add("| :------- | :----- | :---------- |$addedTableDivider")
    }
    else {
        $null = $allLines.Add("`n$leadingHeadingHashtag# Policy Effects by Policy`n")
        $null = $allLines.Add("| Category | Policy |$addedTableHeader")
        $null = $allLines.Add("| :------- | :----- |$addedTableDivider")
        $null = $assignmentsByCategoryHeader.Add("`n$leadingHeadingHashtag# Policy Effects by Policy`n")
        $null = $assignmentsByCategoryHeader.Add("| Category | Policy |$addedTableHeader")
        $null = $assignmentsByCategoryHeader.Add("| :------- | :----- |$addedTableDivider")
    }
    
    $flatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # If statement to skip over duplicates
        if ( $true -ne $_.isReferencePathMatch) {
            # Build additional columns
            $addedEffectColumns = ""
            $environmentList = $_.environmentList
            foreach ($environmentCategory in $environmentCategories) {
                if ($environmentList.ContainsKey($environmentCategory)) {
                    $environmentCategoryValues = $environmentList.$environmentCategory
                    $effectValue = $environmentCategoryValues.effectValue
                    if ($effectValue.StartsWith("[if(contains(parameters('resourceTypeList')")) {
                        $effectValue = "SetByParameter"
                    }
                    $effectAllowedValues = $_.effectAllowedValues
                    $text = Convert-EffectToMarkdownString `
                        -Effect $effectValue `
                        -AllowedValues $effectAllowedValues.Keys `
                        -InTableBreak $inTableBreak
                    $addedEffectColumns += " $text |"
                }
                else {
                    $addedEffectColumns += " |"
                }

            }
            $groupNamesText = ""
            if ($DocumentationSpecification.markdownIncludeComplianceGroupNames) {
                $groupNames = $_.groupNames
                if ($groupNames.Count -gt 0) {
                    $sortedGroupNames = $groupNames | Sort-Object -Unique
                    $groupNamesText = "| $($sortedGroupNames -join $inTableBreak) "
                }
                else {
                    $groupNamesText = "| "
                }
            }
            # Add to Main Markdown
            $null = $allLines.Add("| $($_.category) | **$($_.displayName)**$($inTableAfterDisplayNameBreak)$($_.description) $($groupNamesText)|$($addedEffectColumns)")
            # Add to sub-page markdown
            if ($assignmentsByCategory.ContainsKey($_.category)) {   
                $assignmentsByCategory[$_.category].subLines += "| $($_.category) | **$($_.displayName)**$($inTableAfterDisplayNameBreak)$($_.description) $($groupNamesText)|$($addedEffectColumns)"
            }
            else {
                $assignmentsByCategory[$_.category] = @{}
                $assignmentsByCategory[$_.category].subLines = $assignmentsByCategoryHeader
                $assignmentsByCategory[$_.category].subLines += "| $($_.category) | **$($_.displayName)**$($inTableAfterDisplayNameBreak)$($_.description) $($groupNamesText)|$($addedEffectColumns)"
            }
        }
    }
    #endregion Policy Effects

    #region Parameters

    if ($DocumentationSpecification.markdownSuppressParameterSection) {
        Write-Verbose "Suppressing Parameters section in Markdown"
    }
    else {
        $null = $allLines.Add("`n$leadingHeadingHashtag# Policy Parameters by Policy`n")
        $null = $allLines.Add("| Category | Policy |$addedTableHeader")
        $null = $allLines.Add("| :------- | :----- |$addedTableDividerParameters")

        $flatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
            # If statement to skip over duplicates
            if ( $true -ne $_.isReferencePathMatch) {
                # Build additional columns
                $addedParametersColumns = ""
                $environmentList = $_.environmentList
                $hasParameters = $false
                foreach ($environmentCategory in $environmentCategories) {
                    if ($environmentList.ContainsKey($environmentCategory)) {
                        $environmentCategoryValues = $environmentList.$environmentCategory
                        $text = ""
                        $parameters = $environmentCategoryValues.parameters
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
                                # Check for null parameter
                                if ($null -eq $parameter.value) {
                                    # Parse through all assignments
                                    foreach ($assignment in $AssignmentsByEnvironment[$environmentCategory]["assignmentsDetails"].keys) {
                                        # For each policy definitions, look to see if it matches the current policy definition that has a parameter set to null
                                        foreach ($definition in $AssignmentsByEnvironment[$environmentCategory]["assignmentsDetails"][$assignment].policyDefinitions) {
                                            if ($definition.id -eq $_.policyTableId) {
                                                # Once a match is found, search all keys (which are parameter names) and see it matches the parameter we are looking for
                                                foreach ($key in $AssignmentsByEnvironment[$environmentCategory]["assignmentsDetails"][$assignment]["parameters"].keys) {
                                                    if ($key -eq $parameterName) {
                                                        # Use the key value over the $parameterName value due to possible case-sensitivity issues.
                                                        $value = $AssignmentsByEnvironment[$environmentCategory]["assignmentsDetails"][$assignment]["parameters"][$key].defaultValue
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                else {
                                    $value = $parameter.value
                                }
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
                                if ($valueString -match '","') {
                                    $valueString = $valueString -replace '","', '", "'
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
                        $addedParametersColumns += " |"
                    }
                }
                if ($hasParameters) {
                    # Add to main markdown
                    $null = $allLines.Add("| $($_.category) | **$($_.displayName)**$($inTableAfterDisplayNameBreak)$($_.description) |$($addedParametersColumns)")
                    # Add to sub-page markdown
                    if ($assignmentsByCategory.ContainsKey($_.category)) {
                        if ($assignmentsByCategory[$_.category].subLines -match "Policy Parameters by Policy") {
                            $assignmentsByCategory[$_.category].subLines += "| $($_.category) | **$($_.displayName)**$($inTableAfterDisplayNameBreak)$($_.description) |$($addedParametersColumns)"
                        }
                        else {
                            $null = $assignmentsByCategory[$_.category].subLines += "`n$leadingHeadingHashtag# Policy Parameters by Policy`n"
                            $null = $assignmentsByCategory[$_.category].subLines += "| Category | Policy |$addedTableHeader"
                            $null = $assignmentsByCategory[$_.category].subLines += "| :------- | :----- |$addedTableDividerParameters"
                            $assignmentsByCategory[$_.category].subLines += "| $($_.category) | **$($_.displayName)**$($inTableAfterDisplayNameBreak)$($_.description) |$($addedParametersColumns)"
                        }
                    }
                    else {
                        $null = $assignmentsByCategory[$_.category].subLines += "`n$leadingHeadingHashtag# Policy Parameters by Policy`n"
                        $null = $assignmentsByCategory[$_.category].subLines += "| Category | Policy |$addedTableHeader"
                        $null = $assignmentsByCategory[$_.category].subLines += "| :------- | :----- |$addedTableDividerParameters"
                        $assignmentsByCategory[$_.category] = @{}
                        $assignmentsByCategory[$_.category].subLines = $assignmentsByCategoryHeader
                        $assignmentsByCategory[$_.category].subLines += "| $($_.category) | **$($_.displayName)**$($inTableAfterDisplayNameBreak)$($_.description) |$($addedParametersColumns)"
                    }
                }
            }
        }
    }

    #endregion Parameters

    # Output file
    $outputFilePath = "$($OutputPath -replace '[/\\]$', '')/$($fileNameStem).md"
    $allLines | Out-File "$outputFilePath" -Force

    # Output file
    foreach ($key in $assignmentsByCategory.keys | Sort-Object) {
        $fileName = $key -replace ' ', '-'
        $outputFilePath = "$($OutputPathServices -replace '[/\\]$', '')/$($fileName).md"
        $assignmentsByCategory[$key].subLines | Out-File $outputFilePath -Force
    }

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
        # If statement to skip over duplicates and ensure not to include Deprecated Policies
        if ( $true -ne $_.isReferencePathMatch) {
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
            $doNotSkip = $false
            foreach ($environmentCategory in $environmentCategories) {
                if ($environmentList.ContainsKey($environmentCategory)) {
                    $perEnvironment = $environmentList.$environmentCategory

                    # Validate doNotDisableDeprecatedPolicies for env
                    $envPacSelector = $AssignmentsByEnvironment."$($perEnvironment.environmentCategory)".pacEnvironmentSelector
                    $doNotDisableDeprecatedPolicies = $PacEnvironments.$envPacSelector.doNotDisableDeprecatedPolicies

                    if (!$deprecatedHash.ContainsKey($_.name) -or $doNotDisableDeprecatedPolicies) {
                        if ($null -ne $perEnvironment.effectValue) {
                            $rowObj["$($environmentCategory)Effect"] = Convert-EffectToCsvString $perEnvironment.effectValue
                        }
                        else {
                            $rowObj["$($environmentCategory)Effect"] = Convert-EffectToCsvString $_.effectDefault
                        }

                        $text = Convert-ParametersToString -Parameters $perEnvironment.parameters -OutputType "csvValues"
                        $rowObj["$($environmentCategory)Parameters"] = $text
                        $doNotSkip = $true
                    }
                }
            }

            # Add row to spreadsheet
            if ($doNotSkip) {
                $null = $allRows.Add($rowObj)
            }
        }
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
    
    #region PushToWiki
    if ($WikiClonePat) {
        Write-Information "Attempting push to Azure DevOps Wiki"
        # Clone down wiki
        git clone "https://$($WikiClonePat):x-oauth-basic@$($DocumentationSpecification.markdownAdoWikiConfig.adoOrganization).visualstudio.com/$($DocumentationSpecification.markdownAdoWikiConfig.adoProject)/_git/$($DocumentationSpecification.markdownAdoWikiConfig.adoWiki).wiki"
        # Move into folder
        Set-Location -Path "$($DocumentationSpecification.markdownAdoWikiConfig.adoWiki).wiki"
        $branch = git branch
        $branch = $branch.split(" ")[1]
        # Copy main markdown file into wiki
        Copy-Item -Path "../$OutputPath/$($DocumentationSpecification.fileNameStem).md"
        # Configure dummy email and user (required)
        git config user.email "epac-wiki@example.com"
        git config user.name "EPAC Wiki"
        # Add changes to commit
        git add .
        # Check if a folder exist that holds the sub pages
        if (-not (Test-Path -Path "$($DocumentationSpecification.fileNameStem)")) {
            # Create folder if does not exist
            New-Item -Path "$($DocumentationSpecification.fileNameStem)" -ItemType Directory
        }
        # Copy all individual services markdown files
        $services = Get-ChildItem -Path "../$OutputPathServices"
        # Move into folder
        Set-Location -Path "$($DocumentationSpecification.fileNameStem)"
        # Remove files that currently exist in file to ensure fresh updates
        Get-ChildItem -Path . -File | Remove-Item
        # Copy over new individual services markdown files
        foreach ($file in $services) {
            Copy-Item $file .
        }
        # Commit and push up to Wiki
        git add .
        git commit -m "Update wiki with the latest markdown files"
        git push origin "$branch"
        Set-Location "../../"
    }
}
