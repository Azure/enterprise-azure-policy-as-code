#Requires -PSEdition Core

function Out-PolicyAssignmentDocumentationPerEnvironmentToFile {
    [CmdletBinding()]
    param (
        [string]  $outputPath,
        $documentationSpecification,
        [hashtable] $assignmentsByEnvironment
    )

    [string] $fileNameStem = $documentationSpecification.fileNameStem
    [string] $environmentCategory = $documentationSpecification.environmentCategory
    [string] $title = $documentationSpecification.title

    Write-Information "Generating '$title' documentation files '$fileNameStem'."
    $assignmentsDetails = $null
    if ($null -eq $fileNameStem -or $fileNameStem -eq "") {
        Write-Error "fileNameStem not specified" -ErrorAction Stop
    }
    if ($null -eq $environmentCategory -or !$assignmentsByEnvironment.ContainsKey($environmentCategory)) {
        Write-Error "Unknown environmentCategory '$environmentCategory' encountered" -ErrorAction Stop
    }
    if ($null -eq $title -or $title -eq "") {
        Write-Error "title not specified" -ErrorAction Stop
    }

    $assignmentsDetails = $assignmentsByEnvironment.$environmentCategory
    $assignmentsInfo = $assignmentsDetails.assignmentsInfo
    $assignmentArray = $assignmentsDetails.assignmentArray
    $flatPolicyList = $assignmentsDetails.flatPolicyList
    [array] $shortNames = @()
    foreach ($assignmentEntry in $assignmentArray) {
        $shortName = $assignmentEntry.shortName
        $shortNames += $shortName
    }

    #region Markdown

    [System.Collections.Generic.List[string]] $allLines = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $headerAndToc = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]] $body = [System.Collections.Generic.List[string]]::new()

    $null = $headerAndToc.Add("# $title`n")
    $null = $headerAndToc.Add("Auto-generated Policy effect documentation for environment '$($environmentCategory)' grouped by Effect and sorted by Policy category and Policy display name.`n")
    $null = $headerAndToc.Add("## Table of contents`n")

    $null = $headerAndToc.Add("- [Assigned Initiatives](#assigned-initiatives)")
    $null = $body.Add("`n## <a id=`"assigned-initiatives`"></a>Assigned Initiatives`n")
    $addedTableHeader = ""
    $addedTableDivider = ""
    foreach ($assignmentEntry in $assignmentArray) {
        $id = $assignmentEntry.id
        $shortName = $assignmentEntry.shortName
        $assignmentInfo = $assignmentsInfo.$id

        $null = $body.Add("### $($shortName)`n")
        $null = $body.Add("- Display name: $($assignmentInfo.initiativeDisplayName)")
        $null = $body.Add("- Type: $($assignmentInfo.initiativePolicyType)")
        $null = $body.Add("- Category: $($assignmentInfo.initiativeCategory)`n")
        $null = $body.Add("$($assignmentInfo.initiativeDescription)`n")

        $addedTableHeader += " $shortName |"
        $addedTableDivider += " :-------: |"
    }

    $null = $headerAndToc.Add("- [$environmentCategory Scopes](#scopes)")
    $null = $body.Add("## <a id=`"scopes`"></a>$environmentCategory Scopes`n")
    foreach ($scope in $assignmentsDetails.scopes) {
        $null = $body.Add("- $scope")
    }

    $previousOrdinal = -1
    $flatPolicyList.Values | Sort-Object -Property { $_.ordinal }, { $_.category }, { $_.displayName } | ForEach-Object -Process {
        $currentOrdinal = $_.ordinal
        if ($previousOrdinal -ne $currentOrdinal) {

            $heading, $link = Convert-OrdinalToEffectDisplayName -ordinal $currentOrdinal
            $null = $headerAndToc.Add("- [$heading](#$link)")
            $null = $body.Add("`n<br/>`n`n## <a id='$link'></a>$heading`n`n<br/>`n")

            $null = $body.Add("| Category | Policy |$addedTableHeader")
            $null = $body.Add("| :------- | :----- |$addedTableDivider")
            $previousOrdinal = $currentOrdinal
        }

        # Build additional columns
        $allAssignments = $_.allAssignments
        $parameterFragment = ""
        $addedEffectColumns = ""
        foreach ($shortName in $shortNames) {
            if ($allAssignments.ContainsKey($shortName)) {
                $assignmentFlat = $allAssignments.$shortName
                $effectValue = $assignmentFlat.effect
                $effectAllowedValues = $assignmentFlat.effectAllowedValues
                $text = Convert-EffectToString `
                    -effect $effectValue `
                    -allowedValues $effectAllowedValues `
                    -Markdown
                $addedEffectColumns += " $text |"

                $parameters = $assignmentFlat.parameters
                if ($null -ne $parameters -and $parameters.Count -gt 0) {
                    $parameterFragment += "<br/>**$($shortName):**"
                    $text = Convert-ParametersToString -parameters $parameters -Markdown
                    $parameterFragment += $text
                }
            }
            else {
                $addedEffectColumns += "  |"
            }
        }
        $null = $body.Add("| $($_.category) | **$($_.displayName)**<br/>$($_.description)$parameterFragment |$addedEffectColumns")
    }
    $null = $headerAndToc.Add("`n<br/>")
    $null = $allLines.AddRange($headerAndToc)
    $null = $allLines.AddRange($body)

    # Output file
    $outputFilePath = "$($outputPath -replace '[/\\]$','')/$fileNameStem.md"
    $allLines | Out-File $outputFilePath -Force

    #endregion Markdown

}
