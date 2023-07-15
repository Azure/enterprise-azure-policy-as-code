function Out-PolicyExemptions {
    [CmdletBinding()]
    param (
        $Exemptions,
        $Assignments,
        $PacEnvironment,
        $PolicyExemptionsFolder,
        [switch] $OutputJson,
        [switch] $OutputCsv,
        $ExemptionOutputType = "*",
        [string] $FileExtension = "json"
    )

    $numberOfExemptions = $Exemptions.Count
    Write-Information "==================================================================================================="
    Write-Information "Output Exemption list ($numberOfExemptions)"
    Write-Information "==================================================================================================="

    $pacSelector = $PacEnvironment.pacSelector
    $outputPath = "$PolicyExemptionsFolder/$pacSelector"
    if (-not (Test-Path $outputPath)) {
        New-Item $outputPath -Force -ItemType directory
    }

    $exemptionsResult = Confirm-ActiveAzExemptions -Exemptions $Exemptions -Assignments $Assignments
    $policyDefinitionReferenceIdsTransform = @{
        label      = "policyDefinitionReferenceIds"
        expression = {
            ($_.policyDefinitionReferenceIds -join ",").ToString()
        }
    }
    $metadataTransform = @{
        label      = "metadata"
        expression = {
            if ($_.metadata) {
                (ConvertTo-Json $_.metadata -Depth 100 -Compress).ToString()
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

    foreach ($key in $exemptionsResult.Keys) {
        if ($ExemptionOutputType -eq "*" -or $ExemptionOutputType -eq $key) {
            [hashtable] $Exemptions = $exemptionsResult.$key
            Write-Information "Output $key Exemption list ($($Exemptions.Count)) for epac environment '$pacSelector'"

            $valueArray = @() + $Exemptions.Values

            if ($valueArray.Count -gt 0) {

                $stem = "$outputPath/$($key)-exemptions"

                if ($OutputJson) {
                    # JSON Output
                    $jsonArray = @() + $valueArray | Select-Object -Property name, `
                        displayName, `
                        description, `
                        exemptionCategory, `
                        expiresOn, `
                        status, `
                        $expiresInDaysTransform, `
                        scope, `
                        policyAssignmentId, `
                        policyDefinitionReferenceIds, `
                        metadata
                    $jsonFile = "$stem.$FileExtension"
                    if (Test-Path $jsonFile) {
                        Remove-Item $jsonFile
                    }
                    $outputJsonObj = @{
                        exemptions = @($jsonArray)
                    }
                    ConvertTo-Json $outputJsonObj -Depth 100 | Out-File $jsonFile -Force
                }

                if ($OutputCsv) {
                    # Spreadsheet outputs (CSV)
                    $excelArray = @() + $valueArray | Select-Object -Property name, `
                        displayName, `
                        description, `
                        exemptionCategory, `
                        expiresOn, `
                        status, `
                        $expiresInDaysTransform, `
                        scope, `
                        policyAssignmentId, `
                        $policyDefinitionReferenceIdsTransform, `
                        $metadataTransform

                    $csvFile = "$stem.csv"
                    if (Test-Path $csvFile) {
                        Remove-Item $csvFile
                    }
                    $excelArray | ConvertTo-Csv -UseQuotes AsNeeded | Out-File $csvFile -Force
                }
            }
        }
    }
}
