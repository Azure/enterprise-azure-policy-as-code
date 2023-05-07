function Out-PolicyExemptions {
    [CmdletBinding()]
    param (
        $exemptions,
        $assignments,
        $pacEnvironment,
        $policyExemptionsFolder,
        [switch] $outputJson,
        [switch] $outputCsv,
        $exemptionOutputType = "*",
        [string] $fileExtension = "json"
    )

    $numberOfExemptions = $exemptions.Count
    Write-Information "==================================================================================================="
    Write-Information "Output Exemption list ($numberOfExemptions)"
    Write-Information "==================================================================================================="

    $pacSelector = $pacEnvironment.pacSelector
    $outputPath = "$policyExemptionsFolder/$pacSelector"
    if (-not (Test-Path $outputPath)) {
        New-Item $outputPath -Force -ItemType directory
    }

    $exemptionsResult = Confirm-ActiveAzExemptions -exemptions $exemptions -assignments $assignments
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
        if ($exemptionOutputType -eq "*" -or $exemptionOutputType -eq $key) {
            [hashtable] $exemptions = $exemptionsResult.$key
            Write-Information "Output $key Exemption list ($($exemptions.Count)) for epac environment '$pacSelector'"

            $valueArray = @() + $exemptions.Values

            if ($valueArray.Count -gt 0) {

                $stem = "$outputPath/$($key)-exemptions"

                if ($outputJson) {
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
                    $jsonFile = "$stem.$fileExtension"
                    if (Test-Path $jsonFile) {
                        Remove-Item $jsonFile
                    }
                    $outputJsonObj = @{
                        exemptions = @($jsonArray)
                    }
                    ConvertTo-Json $outputJsonObj -Depth 100 | Out-File $jsonFile -Force
                }

                if ($outputCsv) {
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
