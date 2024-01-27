function Out-PolicyExemptions {
    [CmdletBinding()]
    param (
        $Exemptions,
        $Assignments,
        $PacEnvironment,
        $PolicyExemptionsFolder,
        [switch] $OutputJson,
        [switch] $OutputCsv,
        [string] $FileExtension = "json",
        [switch] $ActiveExemptionsOnly
    )

    $numberOfExemptions = $Exemptions.Count
    Write-Information "==================================================================================================="
    Write-Information "Output Exemption list ($numberOfExemptions)"
    Write-Information "==================================================================================================="

    $pacSelector = $PacEnvironment.pacSelector
    $outputPath = "$PolicyExemptionsFolder/$pacSelector"
    if (-not (Test-Path $outputPath)) {
        $null = New-Item $outputPath -Force -ItemType directory
    }

    #region Transformations

    $policyDefinitionReferenceIdsTransform = @{
        label      = "policyDefinitionReferenceIds"
        expression = {
            if ($_.policyDefinitionReferenceIds) {
            ($_.policyDefinitionReferenceIds -join ",").ToString()
            }
            else {
                ''
            }
        }
    }
    $metadataTransformCsv = @{
        label      = "metadata"
        expression = {
            if ($_.metadata) {
                $step1 = Get-CustomMetadata -Metadata $_.metadata -Remove "pacOwnerId"
                $temp = (ConvertTo-Json $step1 -Depth 100 -Compress).ToString()
                if ($temp -eq "{}") {
                    ''
                }
                else {
                    $temp
                }
            }
            else {
                ''
            }
        }
    }
    $metadataTransformJson = @{
        label      = "metadata"
        expression = {
            if ($_.metadata) {
                $temp = Get-CustomMetadata -Metadata $_.metadata -Remove "pacOwnerId"
                $temp
            }
            else {
                $null
            }
        }
    }
    $resourceSelectorsTransform = @{
        label      = "resourceSelectors"
        expression = {
            if ($_.resourceSelectors) {
                (ConvertTo-Json $_.resourceSelectors -Depth 100 -Compress).ToString()
            }
            else {
                ''
            }
        }
    }
    $expiresInDaysTransform = @{
        label      = "expiresInDays"
        expression = {
            if ($_.expiresInDays -eq [Int32]::MaxValue) {
                'n/a'
            }
            else {
                $_.expiresInDays
            }
        }
    }
    $assignmentScopeValidationTransform = @{
        label      = "assignmentScopeValidation"
        expression = {
            if ($_.assignmentScopeValidation) {
                $_.assignmentScopeValidation
            }
            else {
                ''
            }
        }
    }

    #endregion Transformations

    Write-Information ""
    $selectedExemptions = $policyExemptions.Values
    $numberOfExemptions = $selectedExemptions.Count
    if ($ActiveExemptionsOnly) {

        #region Active Exemptions

        $stem = "$outputPath/active-exemptions"
        Write-Information "==================================================================================================="
        Write-Information "Output $numberOfExemptions active (not expired or orphaned) Exemptions for epac environment '$pacSelector'"
        Write-Information "==================================================================================================="
        if ($OutputJson) {
            $selectedArray = $selectedExemptions | Where-Object status -eq "active" | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                scope, `
                policyAssignmentId, `
                policyDefinitionReferenceIds, `
                resourceSelectors, `
                $metadataTransformJson, `
                assignmentScopeValidation
            $jsonArray = @()
            if ($selectedArray -and $selectedArray.Count -gt 0) {
                $jsonArray += $selectedArray
            }
            $jsonFile = "$stem.$FileExtension"
            if (Test-Path $jsonFile) {
                Remove-Item $jsonFile
            }
            $outputJsonObj = [ordered]@{
                '$schema'  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-exemption-schema.json"
                exemptions = $jsonArray
            }
            ConvertTo-Json $outputJsonObj -Depth 100 | Out-File $jsonFile -Force
        }
        if ($OutputCsv) {
            $selectedArray = $selectedExemptions | Where-Object status -eq "active" | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                scope, `
                policyAssignmentId, `
                $policyDefinitionReferenceIdsTransform, `
                $resourceSelectorsTransform, `
                $metadataTransformCsv, `
                $assignmentScopeValidationTransform
            $excelArray = @()
            if ($null -ne $selectedArray -and $selectedArray.Count -gt 0) {
                $excelArray += $selectedArray
            }
            $csvFile = "$stem.csv"
            if (Test-Path $csvFile) {
                Remove-Item $csvFile
            }
            if ($excelArray.Count -gt 0) {
                $excelArray | ConvertTo-Csv -UseQuotes AsNeeded | Out-File $csvFile -Force
            }
            else {
                $columnHeaders = "name,displayName,description,exemptionCategory,expiresOn,scope,policyAssignmentId,policyDefinitionReferenceIds,metadata,assignmentScopeValidation"
                $columnHeaders | Out-File $csvFile -Force
            }
        }

        #endregion Active Exemptions

    }
    else {

        #region All Exemptions

        $stem = "$outputPath/all-exemptions"
        Write-Information "==================================================================================================="
        Write-Information "Output $numberOfExemptions Exemptions (all) for epac environment '$pacSelector'"
        Write-Information "==================================================================================================="
        if ($OutputJson) {
            $selectedArray = $selectedExemptions | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                status, `
                $expiresInDaysTransform, `
                scope, `
                policyAssignmentId, `
                policyDefinitionReferenceIds, `
                resourceSelectors, `
                $metadataTransformJson, `
                assignmentScopeValidation
            $jsonArray = @()
            if ($selectedArray -and $selectedArray.Count -gt 0) {
                $jsonArray += $selectedArray
            }
            $jsonFile = "$stem.$FileExtension"
            if (Test-Path $jsonFile) {
                Remove-Item $jsonFile
            }
            $outputJsonObj = [ordered]@{
                '$schema'  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-exemption-schema.json"
                exemptions = $jsonArray
            }
            ConvertTo-Json $outputJsonObj -Depth 100 | Out-File $jsonFile -Force
        }
        if ($OutputCsv) {
            $selectedArray = $selectedExemptions | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                status, `
                $expiresInDaysTransform, `
                scope, `
                policyAssignmentId, `
                $policyDefinitionReferenceIdsTransform, `
                $resourceSelectorsTransform, `
                $metadataTransformCsv, `
                $assignmentScopeValidationTransform
            $excelArray = @()
            if ($null -ne $selectedArray -and $selectedArray.Count -gt 0) {
                $excelArray += $selectedArray
            }
            $csvFile = "$stem.csv"
            if (Test-Path $csvFile) {
                Remove-Item $csvFile
            }
            if ($excelArray.Count -gt 0) {
                $excelArray | ConvertTo-Csv -UseQuotes AsNeeded | Out-File $csvFile -Force
            }
            else {
                $columnHeaders = "name,displayName,description,exemptionCategory,expiresOn,status,expiresInDays,scope,policyAssignmentId,policyDefinitionReferenceIds,metadata,assignmentScopeValidation"
                $columnHeaders | Out-File $csvFile -Force
            }

        }

        #endregion All Exemptions

    }
}
