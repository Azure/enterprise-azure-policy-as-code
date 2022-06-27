#Requires -PSEdition Core

function Out-PolicyAssignmentDocumentationAcrossEnvironmentsToFile {
    [CmdletBinding()]
    param (
        [string]  $outputPath,
        $documentationSpecification,
        [hashtable] $assignmentsDetailsByEnvironmentCategory
    )

    [string] $fileNameStem = $documentationSpecification.fileNameStem
    [string[]] $environmentCategories = $documentationSpecification.environmentCategories
    [string] $title = $documentationSpecification.title

    Write-Information "Generating '$title' documentation file '$fileNameStem'."

    # Checking parameters
    $assignmentsDetails = $null
    if ($null -eq $fileNameStem -or $fileNameStem -eq "") {
        Write-Error "fileNameStem not specified" -ErrorAction Stop
    }
    if ($null -eq $environmentCategories -or $environmentCategories.Length -eq 0) {
        Write-Error "No environmentCategories '$environmentCategories' specified" -ErrorAction Stop
    }
    else {
        foreach ($environmentCategory in $environmentCategories) {
            if (!$assignmentsDetailsByEnvironmentCategory.ContainsKey($environmentCategory)) {
                Write-Error "Unknown environmentCategory '$environmentCategory' encountered" -ErrorAction Stop
            }
        }
    }
    if ($null -eq $title -or $title -eq "") {
        Write-Error "title not specified" -ErrorAction Stop
    }

    #region Collate the data

    [hashtable] $initiativesFlatList = @{}
    [hashtable] $policyEffectsFlatList = @{}
    foreach ($environmentCategory in $environmentCategories) {
        $assignmentsDetails = $assignmentsDetailsByEnvironmentCategory.$environmentCategory

        # Collate Initiatives
        $assignmentsInfo = $assignmentsDetails.assignmentsInfo
        foreach ($assignmentInfo in $assignmentsInfo.Values) {
            $shortName = $assignmentInfo.shortName
            if (!$initiativesFlatList.ContainsKey($shortName)) {
                $initiativeInfo = @{
                    shortName             = $assignmentInfo.shortName
                    initiativeName        = $assignmentInfo.initiativeName
                    initiativeDisplayName = $assignmentInfo.initiativeDisplayName
                    initiativeDescription = $assignmentInfo.initiativeDescription
                    initiativePolicyType  = $assignmentInfo.initiativePolicyType
                    initiativeCategory    = $assignmentInfo.initiativeCategory
                }
                $null = $initiativesFlatList.Add($shortName, $initiativeInfo)
            }
        }

        # Collate Policies
        $flatPolicyList = $assignmentsDetails.flatPolicyList
        foreach ($id in $flatPolicyList.Keys) {
            $flatPolicyEntry = $flatPolicyList.$id

            [hashtable] $policyEffectsFlatEntry = @{}
            if ($policyEffectsFlatList.ContainsKey($id)) {
                $policyEffectsFlatEntry = $policyEffectsFlatList.$id
                $effectAllowedValuesCurrent = $policyEffectsFlatEntry.effectAllowedValues
                $effectAllowedValuesNew = $flatPolicyEntry.effectAllowedValues
                if ($effectAllowedValuesNew.Count -gt $effectAllowedValuesCurrent.Count) {
                    $policyEffectsFlatEntry.effectAllowedValue = $effectAllowedValuesNew
                }
            }
            else {

                $policyEffectsFlatEntry = @{
                    category            = $flatPolicyEntry.category
                    displayName         = $flatPolicyEntry.displayName
                    description         = $flatPolicyEntry.description
                    effectByEnvironment = @{}
                    effectAllowedValues = $flatPolicyEntry.effectAllowedValues
                }
                $policyEffectsFlatList.Add($id, $policyEffectsFlatEntry)
            }

            $effectiveAssignment = $flatPolicyEntry.effectiveAssignment
            $effect = $effectiveAssignment.effect
            $effectByEnvironment = $policyEffectsFlatEntry.effectByEnvironment
            $effectByEnvironment.Add($environmentCategory, $effect)
        }
    }

    #endregion Collate the data

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $headerAndToc = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $body = [System.Collections.Generic.List[string]]::new()
    $null = $headerAndToc.Add("# $title`n")
    $null = $headerAndToc.Add("Auto-generaed Policy effect documentation across environments '$($environmentCategories -join "', '")' sorted by Policy category and Policy display name.`n")
    $null = $headerAndToc.Add("## Table of contents`n")

    $null = $headerAndToc.Add("- [Assigned Initiatives](#assigned-initiatives)")
    $null = $body.Add("`n## <a id=`"assigned-initiatives`"></a>Assigned Initiatives`n")
    $initiativesFlatList.Values | Sort-Object -Property { $_.initiativeDisplayName } | ForEach-Object -Process {
        $null = $body.Add("### $($_.initiativeDisplayName)`n")
        $null = $body.Add("- Type: $($_.initiativePolicyType)")
        $null = $body.Add("- Category: $($_.initiativeCategory)`n")
        $null = $body.Add("$($_.initiativeDescription)`n")
    }

    $null = $headerAndToc.Add("- [Scopes](#scopes)")
    $null = $body.Add("## <a id=`"scopes`"></a>Scopes`n")
    $addedTableHeader = ""
    $addedTableDivider = ""
    foreach ($environmentCategory in $environmentCategories) {
        $assignmentsDetails = $assignmentsDetailsByEnvironmentCategory.$environmentCategory
        $null = $body.Add("- '$environmentCategory' environment scopes:")
        foreach ($scope in $assignmentsDetails.scopes) {
            $null = $body.Add("  - $scope")
        }
        $addedTableHeader += " $environmentCategory |"
        $addedTableDivider += " :-----------------: |"
    }

    $null = $headerAndToc.Add("- [Policy effects across environments](#policy-effects-across-environment)")
    $null = $body.Add("`n<br/>`n`n## <a id='policy-effects-across-environment'></a>Policy effects across environment`n`n<br/>`n")
    $null = $body.Add("| Category | Policy |$addedTableHeader")
    $null = $body.Add("| :------- | :----- |$addedTableDivider")

    $policyEffectsFlatList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # Build additional columns
        $addedEffectColumns = ""
        $effectByEnvironment = $_.effectByEnvironment
        foreach ($environmentCategory in $environmentCategories) {
            if ($effectByEnvironment.ContainsKey($environmentCategory)) {
                $effect = Convert-EffectToShortForm -effect  $effectByEnvironment.$environmentCategory
                $addedEffectColumns += " $effect |"
            }
            else {
                $addedEffectColumns += "  |"
            }
        }
        $null = $body.Add("| $($_.category) | **$($_.displayName)**<br/>$($_.description) | $addedEffectColumns")
    }
    $null = $allLines.AddRange($headerAndToc)
    $null = $allLines.AddRange($body)
    
    # Output file
    $outputFilePath = "$($outputPath -replace '[/\\]$', '')/$fileNameStem.md"
    $allLines | Out-File $outputFilePath -Force

    #endregion Markdown

    #region csv

    # Create header row
    $allLines.Clear()
    [System.Collections.ArrayList] $cells = [System.Collections.ArrayList]::new()
    $null = $cells.AddRange(@("Category", "Policy", "Description"))
    foreach ($environmentCategory in $environmentCategories) {
        $null = $cells.Add($environmentCategory)
    }
    $headerString = Convert-ListToToCsvRow($cells) 
    $null = $allLines.Add($headerString)

    $policyEffectsFlatList.Values | Sort-Object -Property { $_.category }, { $_.displayName } | ForEach-Object -Process {
        # Build common columns
        $cells.Clear()
        $null = $cells.AddRange(@($_.category, $_.displayName, $_.description))

        $effectByEnvironment = $_.effectByEnvironment
        # Build effect by environmentCategory columns
        foreach ($environmentCategory in $environmentCategories) {
            if ($effectByEnvironment.ContainsKey($environmentCategory)) {
                $effect = Convert-EffectToShortForm -effect $effectByEnvironment.$environmentCategory
                $null = $cells.Add($effect)
            }
            else {
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

}
