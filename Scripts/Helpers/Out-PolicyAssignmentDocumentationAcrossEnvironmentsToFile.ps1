#Requires -PSEdition Core

function Out-PolicyAssignmentDocumentationAcrossEnvironmentsToFile {
    [CmdletBinding()]
    param (
        [string]  $outputPath,
        $documentationSpecification,
        [hashtable] $initiativeInfos,
        [hashtable] $assignmentsByEnvironment
    )

    [string] $fileNameStem = $documentationSpecification.fileNameStem
    [string[]] $environmentCategories = $documentationSpecification.environmentCategories
    [string] $title = $documentationSpecification.title

    Write-Information "Generating '$title' documentation file '$fileNameStem'."

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
        if (-not $assignmentsByEnvironment.ContainsKey($environmentCategory)) {
            # Should never happen (programing bug)
            Write-Error "Unknown environmentCategory '$environmentCategory' encountered - bug in EPAC PowerShell code" -ErrorAction Stop
        }

        # Collate Policies
        $perEnvironment = $assignmentsByEnvironment.$environmentCategory
        $flatPolicyList = $perEnvironment.flatPolicyList
        foreach ($policyTableId in $flatPolicyList.Keys) {
            $flatPolicyEntry = $flatPolicyList.$policyTableId

            $flatPolicyEntryAcrossEnvironments = @{}
            if ($flatPolicyListAcrossEnvironments.ContainsKey($policyTableId)) {
                $flatPolicyEntryAcrossEnvironments = $flatPolicyListAcrossEnvironments.$policyTableId
            }
            else {
                $flatPolicyEntryAcrossEnvironments = @{
                    policyTableId       = $policyTableId
                    name                = $flatPolicyEntry.name
                    referencePath       = $flatPolicyEntry.ReferencePath
                    displayName         = $flatPolicyEntry.displayName
                    description         = $flatPolicyEntry.description
                    policyType          = $flatPolicyEntry.policyType
                    category            = $flatPolicyEntry.category
                    ordinal             = 99
                    effectAllowedValues = @{}
                    groupNames          = @{}
                    environmentList     = @{}
                    initiativeList      = @{}
                }
                $flatPolicyListAcrossEnvironments.Add($policyTableId, $flatPolicyEntryAcrossEnvironments)
            }

            # Find out lowest ordinal for grouping (optional)
            if ($flatPolicyEntry.ordinal -lt $flatPolicyEntryAcrossEnvironments.ordinal) {
                $flatPolicyEntryAcrossEnvironments.ordinal = $flatPolicyEntry.ordinal
            }

            # Collect union of all effect parameter allowed values
            $effectAllowedValues = $flatPolicyEntryAcrossEnvironments.effectAllowedValues
            foreach ($allowedValue in $flatPolicyEntry.effectAllowedValues.Keys) {
                if (-not $effectAllowedValues.ContainsKey($allowedValue)) {
                    $NULL = $effectAllowedValues.Add($allowedValue, $allowedValue)
                }
            }

            # Collect union of all group names
            $flatPolicyEntryGroupNames = $flatPolicyEntry.groupNames
            $groupNames = $flatPolicyEntryAcrossEnvironments.groupNames
            if ($null -ne $flatPolicyEntryGroupNames -and $flatPolicyEntryGroupNames.Count -gt 0) {
                foreach ($groupName in $flatPolicyEntryGroupNames.Keys) {
                    if (-not $groupNames.ContainsKey($groupName)) {
                        $null = $groupNames.Add($groupName, $groupName)
                    }
                }
            }

            # Collect environment category specific items
            $environmentList = $flatPolicyEntryAcrossEnvironments.environmentList
            if ($environmentList.ContainsKey($environmentCategory)) {
                Write-Error "Duplicate environmentCategory '$environmentCategory' encountered - bug in EPAC PowerShell code" -ErrorAction Stop
            }
            $effectValue = "Unknown"
            if ($null -ne $flatPolicyEntry.effectValue) {
                $effectValue = $flatPolicyEntry.effectValue
            }
            else {
                $effectValue = $flatPolicyEntry.effectDefault
            }
            $environmentCategoryInfo = @{
                environmentCategory = $environmentCategory
                effectValue         = $effectValue
                parameters          = $flatPolicyEntry.parameters
                initiativesList     = $flatPolicyEntry.initiativeList
            }
            $null = $environmentList.Add($environmentCategory, $environmentCategoryInfo)

            # Collect initiative specific items
            $initiativeList = $flatPolicyEntryAcrossEnvironments.initiativeList
            $flatPolicyEntryInitiativeList = $flatPolicyEntry.initiativeList
            foreach ($shortName in $flatPolicyEntryInitiativeList.Keys) {
                $initiativeInfo = $flatPolicyEntryInitiativeList.$shortName
                if (-not $initiativeList.ContainsKey($shortName)) {
                    $initiativeEntry = @{
                        shortName             = $shortName
                        id                    = $initiativeInfo.id
                        name                  = $initiativeInfo.name
                        displayName           = $initiativeInfo.displayName
                        description           = $initiativeInfo.description
                        policyType            = $initiativeInfo.policyType
                        effectParameterName   = $initiativeInfo.effectParameterName
                        effectDefault         = $initiativeInfo.effectDefault
                        effectAllowedValues   = $initiativeInfo.effectAllowedValues
                        effectReason          = $initiativeInfo.effectReason
                        isEffectParameterized = $initiativeInfo.isEffectParameterized
                        parameters            = $initiativeInfo.parameters
                    }
                    $null = $initiativeList.Add($shortName, $initiativeEntry)
                }
            }
        }
    }

    #endregion Combine per environment flat lists into a single flat list ($flatPolicyListAcrossEnvironments)

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $headerAndToc = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $body = [System.Collections.Generic.List[string]]::new()

    $markdownOutputTypes = @( "full", "summary" )
    $markdownOutputTypes = @( "summary" )

    foreach ($markdownOutputType in $markdownOutputTypes) {
        $fullOutput = $markdownOutputType -eq "full"

        $allLines.Clear()
        $headerAndToc.Clear()
        $body.Clear()

        #region Overview
        $null = $headerAndToc.Add("# $title`n")
        $null = $headerAndToc.Add("Auto-generated Policy effect documentation across environments '$($environmentCategories -join "', '")' sorted by Policy category and Policy display name.`n")
        $null = $headerAndToc.Add("## Table of contents`n")

        $null = $headerAndToc.Add("- [Environments](#environments)")
        $null = $body.Add("`n## <a id=`"environments`"></a>Environments`n")
        $addedTableHeader = ""
        $addedTableDivider = ""
        foreach ($environmentCategory in $environmentCategories) {
            $perEnvironment = $assignmentsByEnvironment.$environmentCategory
            $itemList = $perEnvironment.itemList
            $assignmentsInfos = $perEnvironment.assignmentsInfos
            $scopes = $perEnvironment.scopes
            $null = $body.Add("`n### **Environment $environmentCategory**")

            $null = $body.Add("`nScopes`n")
            foreach ($scope in $scopes) {
                $null = $body.Add("- $scope")
            }

            foreach ($item in $itemList) {
                $assignmentId = $item.assignmentId
                if ($assignmentsInfos.ContainsKey($assignmentId)) {
                    # should always be true
                    $assignmentInfo = $assignmentsInfos.$assignmentId
                    $null = $body.Add("`nAssignment $($assignmentInfo.assignment.displayName)`n")
                    $null = $body.Add("- Initiative: $($assignmentInfo.displayName)")
                    $null = $body.Add("- Type: $($assignmentInfo.policyType)")
                    $null = $body.Add("- Category: $($assignmentInfo.category)")
                    $null = $body.Add("- Description: $($assignmentInfo.description)")
                }
            }

            # Calculate environment columns
            $addedTableHeader += " $environmentCategory |"
            $addedTableDivider += " :-----: |"
        }

        #endregion Overview

        #region Policy Table

        $null = $headerAndToc.Add("- [Policy effects across environments](#policy-effects-across-environment)")
        $null = $body.Add("`n<br/>`n`n## <a id='policy-effects-across-environment'></a>Policy effects across environment`n`n<br/>`n")
        $null = $body.Add("| Category | Policy |$addedTableHeader")
        $null = $body.Add("| :------- | :----- |$addedTableDivider")

        $flatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
            # Build additional columns
            $addedEffectColumns = ""
            $environmentList = $_.environmentList
            $parameterFragment = ""
            foreach ($environmentCategory in $environmentCategories) {
                if ($environmentList.ContainsKey($environmentCategory)) {
                    $environmentCategoryValues = $environmentList.$environmentCategory
                    $effectValue = $environmentCategoryValues.effectValue
                    $effectAllowedValues = $_.effectAllowedValues
                    $text = Convert-EffectToString `
                        -effect $effectValue `
                        -allowedValues $effectAllowedValues.Keys `
                        -Markdown
                    $addedEffectColumns += " $text |"

                    # Todo: Full output (needs clean design)
                    # if ($null -ne $parameters -and $parameters.Count -gt 0) {
                    #     $parameterFragment += "<br/>**$($environmentCategory):**"
                    #     $text = Convert-ParametersToString -parameters $parameters -Markdown
                    #     $parameterFragment += $text
                    # }
                    # [array] $groupNames = $perInitiative.groupNames
                    # $parameters = $perInitiative.parameters
                    # if ($parameters.Count -gt 0 -or $groupNames.Count -gt 0) {
                    #     $addedRows += "<br/>**$($perInitiative.displayName):**"
                    #     $text = Convert-ParametersToString -parameters $parameters -outputType "markdown"
                    #     $addedRows += $text
                    #     foreach ($groupName in $groupNames) {
                    #         $addedRows += "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$groupName"
                    #     }
                    # }
                }
                else {
                    $addedEffectColumns += " |"
                }
            }
            $null = $body.Add("| $($_.category) | **$($_.displayName)**<br/>$($_.description)$($parameterFragment) | $($addedEffectColumns)")
        }
        $null = $allLines.AddRange($headerAndToc)
        $null = $allLines.AddRange($body)

        #endregion Policy Table

        # Output file
        $outputFilePath = "$($outputPath -replace '[/\\]$', '')/$($fileNameStem)-$($markdownOutputType).md"
        $allLines | Out-File $outputFilePath -Force

    }

    #endregion Markdown

    #region csv

    $csvOutputTypes = @( "full", "parameters" )

    foreach ($csvOutputType in $csvOutputTypes) {
        $fullOutput = $csvOutputType -eq "full"

        # Create header rows for CSV
        [System.Collections.ArrayList] $allRows = [System.Collections.ArrayList]::new()
        [System.Collections.ArrayList] $columnHeaders = [System.Collections.ArrayList]::new()
        $null = $columnHeaders.AddRange(@("name", "referencePath", "category", "displayName", "description" ))
        if ($fullOutput) {
            $null = $columnHeaders.Add("groupNames")
        }
        $null = $columnHeaders.Add("allowedEffects")
        foreach ($environmentCategory in $environmentCategories) {
            $null = $columnHeaders.Add("$($environmentCategory)_Effect")
        }
        foreach ($environmentCategory in $environmentCategories) {
            $null = $columnHeaders.Add("$($environmentCategory)_Parameters")
        }

        if ($fullOutput) {
            $initiativeShortNames = @()
            foreach ($environmentCategory in $environmentCategories) {
                $perEnvironment = $assignmentsByEnvironment.$environmentCategory
                $itemList = $perEnvironment.itemList
                foreach ($item in $itemList) {
                    $shortName = $item.shortName
                    $null = $columnHeaders.Add("$($environmentCategory)-$($shortName)-Effect")
                    if (-not ($shortName -in $initiativeShortNames)) {
                        $initiativeShortNames += $shortName
                    }
                }
            }
            foreach ($shortName in $initiativeShortNames) {
                $null = $columnHeaders.Add("$($shortName)-ParameterDefinitions")
            }
        }

        # Process the table
        $flatPolicyListAcrossEnvironments.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {

            # Initialize row - with empty strings
            $rowObj = [ordered]@{}
            foreach ($key in $columnHeaders) { $null = $rowObj.Add($key, "") }

            # Build common columns
            $rowObj.name = $_.name
            $rowObj.referencePath = $_.referencePath
            $rowObj.category = $_.category
            $rowObj.displayName = $_.displayName
            $rowObj.description = $_.description
            if ($_.effectAllowedValues.Count -gt 0) {
                $rowObj.allowedEffects = $_.effectAllowedValues.Keys -join ", "
            }
            if ($fullOutput) {
                if ($_.groupNames.Count -gt 0) {
                    $rowObj.groupNames = $_.groupNames.Keys -join ", "
                }
            }

            $environmentList = $_.environmentList
            # Build environmentCategory columns
            foreach ($environmentCategory in $environmentCategories) {
                if ($environmentList.ContainsKey($environmentCategory)) {
                    $perEnvironment = $environmentList.$environmentCategory
                    if ($null -ne $perEnvironment.effectValue) {
                        $rowObj["$($environmentcategory)_Effect"] = $perEnvironment.effectValue
                    }

                    $text = Convert-ParametersToString -parameters $perEnvironment.parameters -outputType "csvValues"
                    $rowObj["$($environmentCategory)_Parameters"] = $text

                    if ($fullOutput) {
                        $perEnvironmentInitiativesList = $perEnvironment.initiativesList
                        foreach ($shortName in $perEnvironmentInitiativesList.Keys) {
                            $initiative = $perEnvironmentInitiativesList.$shortName
                            if ($initiative.isEffectParameterized) {
                                $rowObj["$($environmentCategory)-$($shortName)-Effect"] = $initiative.effectValueString
                            }
                            else {
                                $rowObj["$($environmentCategory)-$($shortName)-Effect"] = $initiative.effectDefaultString
                            }
                        }
                    }
                }
            }

            if ($fullOutput) {
                $initiativeList = $_.initiativeList
                foreach ($shortName in $initiativeShortNames) {
                    if ($initiativeList.ContainsKey($shortName)) {
                        $perInitiative = $initiativeList.$shortName
                        $text = Convert-ParametersToString -parameters $perInitiative.parameters -outputType "csvDefinitions"
                        $rowObj["$($shortName)-ParameterDefinitions"] = $text
                    }
                }
            }

            # Add row to spreadsheet
            $null = $allRows.Add($rowObj)
        }

        # Output file
        $outputFilePath = "$($outputPath -replace '[/\\]$','')/$($fileNameStem)-$($csvOutputType).csv"
        $allRows | ConvertTo-Csv | Out-File $outputFilePath -Force

    }

    #endregion csv

}
