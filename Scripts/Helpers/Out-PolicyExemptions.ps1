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

    $PacSelector = $PacEnvironment.pacSelector
    $OutputPath = "$PolicyExemptionsFolder/$PacSelector"
    if (-not (Test-Path $OutputPath)) {
        New-Item $OutputPath -Force -ItemType directory
    }

    $ExemptionsResult = Confirm-ActiveAzExemptions -Exemptions $Exemptions -Assignments $Assignments
    $PolicyDefinitionReferenceIdsTransform = @{
        label      = "policyDefinitionReferenceIds"
        expression = {
            ($_.policyDefinitionReferenceIds -join ",").ToString()
        }
    }
    $MetadataTransform = @{
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

    foreach ($key in $ExemptionsResult.Keys) {
        if ($ExemptionOutputType -eq "*" -or $ExemptionOutputType -eq $key) {
            [hashtable] $Exemptions = $ExemptionsResult.$key
            Write-Information "Output $key Exemption list ($($Exemptions.Count)) for epac environment '$PacSelector'"

            $valueArray = @() + $Exemptions.Values

            if ($valueArray.Count -gt 0) {

                $stem = "$OutputPath/$($key)-Exemptions"

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
                    $OutputJsonObj = @{
                        exemptions = @($jsonArray)
                    }
                    ConvertTo-Json $OutputJsonObj -Depth 100 | Out-File $jsonFile -Force
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
                        $PolicyDefinitionReferenceIdsTransform, `
                        $MetadataTransform

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
