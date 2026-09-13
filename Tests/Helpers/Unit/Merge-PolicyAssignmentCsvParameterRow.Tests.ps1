BeforeAll {
    $helperPath = Join-Path $PSScriptRoot "../../../Scripts/Helpers/Merge-PolicyAssignmentCsvParameterRow.ps1"
    $operationPath = Join-Path $PSScriptRoot "../../../Scripts/Operations/Update-PolicyAssignmentCsvParameterFile.ps1"
    . $helperPath
}

Describe "Merge-PolicyAssignmentCsvParameterRow" {
    It "refreshes metadata while preserving assignment values and custom columns" {
        $generatedRows = @(
            [pscustomobject][ordered]@{
                name            = "alpha"
                referencePath   = ""
                displayName     = "Alpha updated"
                allowedEffects  = "parameter: Audit,Deny"
                prodEffect      = "Audit"
                prodParameters  = "generated"
            },
            [pscustomobject][ordered]@{
                name            = "new-policy"
                referencePath   = ""
                displayName     = "New policy"
                allowedEffects  = "parameter: Audit"
                prodEffect      = "Audit"
                prodParameters  = "new-default"
            }
        )
        $existingRows = @(
            [pscustomobject][ordered]@{
                name                  = "alpha"
                referencePath         = ""
                displayName           = "Old Alpha"
                allowedEffects        = "old metadata"
                prodEffect            = "Deny"
                prodParameters        = "preserved"
                nonComplianceMessages = "Keep this message"
                owner                 = "Platform"
            },
            [pscustomobject][ordered]@{
                name                  = "removed-policy"
                referencePath         = ""
                displayName           = "Removed policy"
                allowedEffects        = "parameter: Audit"
                prodEffect            = "Audit"
                prodParameters        = ""
                nonComplianceMessages = "Remove this row"
                owner                 = "Platform"
            }
        )

        $result = Merge-PolicyAssignmentCsvParameterRow `
            -GeneratedRows $generatedRows `
            -ExistingRows $existingRows

        $result.Headers | Should -Be @(
            "name",
            "referencePath",
            "displayName",
            "allowedEffects",
            "prodEffect",
            "prodParameters",
            "nonComplianceMessages",
            "owner"
        )
        $result.Rows.Count | Should -Be 2
        $result.Rows[0].displayName | Should -Be "Alpha updated"
        $result.Rows[0].allowedEffects | Should -Be "parameter: Audit,Deny"
        $result.Rows[0].prodEffect | Should -Be "Deny"
        $result.Rows[0].prodParameters | Should -Be "preserved"
        $result.Rows[0].nonComplianceMessages | Should -Be "Keep this message"
        $result.Rows[0].owner | Should -Be "Platform"
        $result.Rows[1].prodEffect | Should -Be "Audit"
        $result.Rows[1].prodParameters | Should -Be "new-default"
        $result.Rows[1].nonComplianceMessages | Should -Be ""
        $result.Rows[1].owner | Should -Be ""
        $result.AddedCount | Should -Be 1
        $result.UpdatedCount | Should -Be 1
        $result.RemovedCount | Should -Be 1
    }

    It "uses name and referencePath as a case-insensitive composite identity" {
        $generatedRows = @(
            [pscustomobject][ordered]@{
                name           = "shared-policy"
                referencePath  = "set-a\ref-1"
                displayName    = "First updated"
                prodEffect     = "Audit"
                prodParameters = ""
            },
            [pscustomobject][ordered]@{
                name           = "shared-policy"
                referencePath  = "set-b\ref-2"
                displayName    = "Second updated"
                prodEffect     = "Audit"
                prodParameters = ""
            }
        )
        $existingRows = @(
            [pscustomobject][ordered]@{
                name           = "SHARED-POLICY"
                referencePath  = "SET-B\REF-2"
                displayName    = "Second old"
                prodEffect     = "Deny"
                prodParameters = "second"
            },
            [pscustomobject][ordered]@{
                name           = "shared-policy"
                referencePath  = "set-a\ref-1"
                displayName    = "First old"
                prodEffect     = "Disabled"
                prodParameters = "first"
            }
        )

        $result = Merge-PolicyAssignmentCsvParameterRow `
            -GeneratedRows $generatedRows `
            -ExistingRows $existingRows

        $result.Rows.name | Should -Be @("shared-policy", "shared-policy")
        $result.Rows.prodEffect | Should -Be @("Disabled", "Deny")
        $result.Rows.prodParameters | Should -Be @("first", "second")
        $result.AddedCount | Should -Be 0
        $result.UpdatedCount | Should -Be 2
        $result.RemovedCount | Should -Be 0
    }

    It "rejects <source> rows missing the <column> column" -TestCases @(
        @{
            source = "generated"
            column = "name"
            generatedRows = @([pscustomobject]@{ referencePath = ""; prodEffect = "Audit" })
            existingRows = @([pscustomobject]@{ name = "alpha"; referencePath = ""; prodEffect = "Deny" })
        },
        @{
            source = "existing parameter"
            column = "referencePath"
            generatedRows = @([pscustomobject]@{ name = "alpha"; referencePath = ""; prodEffect = "Audit" })
            existingRows = @([pscustomobject]@{ name = "alpha"; prodEffect = "Deny" })
        }
    ) {
        {
            Merge-PolicyAssignmentCsvParameterRow `
                -GeneratedRows $generatedRows `
                -ExistingRows $existingRows
        } | Should -Throw "*$source CSV must contain the '$column' column*"
    }

    It "rejects duplicate identities in the <source> CSV" -TestCases @(
        @{
            source = "generated"
            generatedRows = @(
                [pscustomobject]@{ name = "alpha"; referencePath = ""; prodEffect = "Audit" },
                [pscustomobject]@{ name = "ALPHA"; referencePath = ""; prodEffect = "Deny" }
            )
            existingRows = @([pscustomobject]@{ name = "alpha"; referencePath = ""; prodEffect = "Deny" })
        },
        @{
            source = "existing parameter"
            generatedRows = @([pscustomobject]@{ name = "alpha"; referencePath = ""; prodEffect = "Audit" })
            existingRows = @(
                [pscustomobject]@{ name = "alpha"; referencePath = ""; prodEffect = "Deny" },
                [pscustomobject]@{ name = "ALPHA"; referencePath = ""; prodEffect = "Audit" }
            )
        }
    ) {
        {
            Merge-PolicyAssignmentCsvParameterRow `
                -GeneratedRows $generatedRows `
                -ExistingRows $existingRows
        } | Should -Throw "*$source CSV contains duplicate rows*"
    }
}

Describe "Update-PolicyAssignmentCsvParameterFile" {
    BeforeEach {
        $generatedPath = Join-Path $TestDrive "generated.csv"
        $parameterPath = Join-Path $TestDrive "parameters.csv"
        @(
            [pscustomobject][ordered]@{
                name           = "alpha"
                referencePath  = ""
                displayName    = "Alpha updated"
                prodEffect     = "Audit"
                prodParameters = "generated"
            },
            [pscustomobject][ordered]@{
                name           = "new-policy"
                referencePath  = ""
                displayName    = "New policy"
                prodEffect     = "Audit"
                prodParameters = "default"
            }
        ) | ConvertTo-Csv | Set-Content -LiteralPath $generatedPath -Encoding utf8NoBOM
        @(
            [pscustomobject][ordered]@{
                name           = "alpha"
                referencePath  = ""
                displayName    = "Alpha old"
                prodEffect     = "Deny"
                prodParameters = "preserved"
                owner          = "Platform"
            },
            [pscustomobject][ordered]@{
                name           = "removed-policy"
                referencePath  = ""
                displayName    = "Removed"
                prodEffect     = "Audit"
                prodParameters = ""
                owner          = "Platform"
            }
        ) | ConvertTo-Csv | Set-Content -LiteralPath $parameterPath -Encoding utf8NoBOM
    }

    It "updates the specified parameter CSV in place" {
        & $operationPath `
            -GeneratedCsvPath $generatedPath `
            -ParameterCsvPath $parameterPath `
            -InformationAction SilentlyContinue

        $updatedRows = @(Import-Csv -LiteralPath $parameterPath)
        $updatedRows.name | Should -Be @("alpha", "new-policy")
        $updatedRows[0].displayName | Should -Be "Alpha updated"
        $updatedRows[0].prodEffect | Should -Be "Deny"
        $updatedRows[0].prodParameters | Should -Be "preserved"
        $updatedRows[0].owner | Should -Be "Platform"
        $updatedRows[1].owner | Should -Be ""

        $bytes = [System.IO.File]::ReadAllBytes($parameterPath)
        @($bytes[0], $bytes[1], $bytes[2]) | Should -Not -Be @(0xEF, 0xBB, 0xBF)
    }

    It "preserves <lineEndingName> line endings and UTF-8 BOM state" -TestCases @(
        @{ lineEndingName = "LF"; lineEnding = "`n"; hasBom = $false },
        @{ lineEndingName = "CRLF"; lineEnding = "`r`n"; hasBom = $true }
    ) {
        $encoding = [System.Text.UTF8Encoding]::new($hasBom)
        $existingRows = @(
            [pscustomobject][ordered]@{
                name           = "alpha"
                referencePath  = ""
                displayName    = "Alpha old"
                prodEffect     = "Deny"
                prodParameters = "preserved"
            }
        )
        $existingText = (($existingRows | ConvertTo-Csv) -join $lineEnding) + $lineEnding
        [System.IO.File]::WriteAllText($parameterPath, $existingText, $encoding)

        & $operationPath `
            -GeneratedCsvPath $generatedPath `
            -ParameterCsvPath $parameterPath `
            -InformationAction SilentlyContinue

        $bytes = [System.IO.File]::ReadAllBytes($parameterPath)
        if ($hasBom) {
            @($bytes[0], $bytes[1], $bytes[2]) | Should -Be @(0xEF, 0xBB, 0xBF)
        }
        else {
            @($bytes[0], $bytes[1], $bytes[2]) | Should -Not -Be @(0xEF, 0xBB, 0xBF)
        }

        $updatedText = $encoding.GetString($bytes)
        if ($lineEnding -eq "`r`n") {
            $updatedText.Replace("`r`n", "") | Should -Not -Match "`n"
        }
        else {
            $updatedText | Should -Not -Match "`r`n"
        }
    }

    It "does not modify the parameter CSV with WhatIf" {
        $before = Get-Content -LiteralPath $parameterPath -Raw

        & $operationPath `
            -GeneratedCsvPath $generatedPath `
            -ParameterCsvPath $parameterPath `
            -WhatIf

        Get-Content -LiteralPath $parameterPath -Raw | Should -BeExactly $before
    }

    It "does not modify the parameter CSV when reconciliation fails" {
        @(
            [pscustomobject]@{ name = "alpha"; referencePath = ""; prodEffect = "Audit" },
            [pscustomobject]@{ name = "ALPHA"; referencePath = ""; prodEffect = "Deny" }
        ) | ConvertTo-Csv | Set-Content -LiteralPath $generatedPath -Encoding utf8NoBOM
        $before = Get-Content -LiteralPath $parameterPath -Raw

        {
            & $operationPath `
                -GeneratedCsvPath $generatedPath `
                -ParameterCsvPath $parameterPath `
                -InformationAction SilentlyContinue
        } | Should -Throw "*generated CSV contains duplicate rows*"

        Get-Content -LiteralPath $parameterPath -Raw | Should -BeExactly $before
    }
}
