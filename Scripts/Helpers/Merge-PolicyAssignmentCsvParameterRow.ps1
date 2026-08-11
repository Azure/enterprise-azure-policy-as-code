function Merge-PolicyAssignmentCsvParameterRow {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]] $GeneratedRows,

        [Parameter(Mandatory = $true)]
        [object[]] $ExistingRows
    )

    if ($GeneratedRows.Count -eq 0) {
        throw "The generated CSV must contain at least one data row."
    }
    if ($ExistingRows.Count -eq 0) {
        throw "The existing parameter CSV must contain at least one data row."
    }

    $generatedHeaders = @($GeneratedRows[0].PSObject.Properties.Name)
    $existingHeaders = @($ExistingRows[0].PSObject.Properties.Name)
    $requiredHeaders = @("name", "referencePath")

    $generatedHeaderLookup = @{}
    foreach ($header in $generatedHeaders) {
        if ($generatedHeaderLookup.ContainsKey($header)) {
            throw "The generated CSV contains duplicate column '$header'."
        }
        $generatedHeaderLookup[$header] = $header
    }

    $existingHeaderLookup = @{}
    foreach ($header in $existingHeaders) {
        if ($existingHeaderLookup.ContainsKey($header)) {
            throw "The existing parameter CSV contains duplicate column '$header'."
        }
        $existingHeaderLookup[$header] = $header
    }

    foreach ($requiredHeader in $requiredHeaders) {
        if (-not $generatedHeaderLookup.ContainsKey($requiredHeader)) {
            throw "The generated CSV must contain the '$requiredHeader' column."
        }
        if (-not $existingHeaderLookup.ContainsKey($requiredHeader)) {
            throw "The existing parameter CSV must contain the '$requiredHeader' column."
        }
    }

    $separator = [char]31
    $getIdentity = {
        param (
            [object] $Row,
            [hashtable] $HeaderLookup,
            [string] $SourceName
        )

        $name = [string]$Row.($HeaderLookup["name"])
        $referencePath = [string]$Row.($HeaderLookup["referencePath"])
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "The $SourceName CSV contains a row with an empty 'name' value."
        }

        return "$($name.ToLowerInvariant())$separator$($referencePath.ToLowerInvariant())"
    }

    $existingRowsByIdentity = @{}
    foreach ($row in $ExistingRows) {
        $identity = & $getIdentity $row $existingHeaderLookup "existing parameter"
        if ($existingRowsByIdentity.ContainsKey($identity)) {
            throw "The existing parameter CSV contains duplicate rows for name '$($row.($existingHeaderLookup["name"]))' and referencePath '$($row.($existingHeaderLookup["referencePath"]))'."
        }
        $existingRowsByIdentity[$identity] = $row
    }

    $generatedIdentities = @{}
    foreach ($row in $GeneratedRows) {
        $identity = & $getIdentity $row $generatedHeaderLookup "generated"
        if ($generatedIdentities.ContainsKey($identity)) {
            throw "The generated CSV contains duplicate rows for name '$($row.($generatedHeaderLookup["name"]))' and referencePath '$($row.($generatedHeaderLookup["referencePath"]))'."
        }
        $generatedIdentities[$identity] = $true
    }

    [System.Collections.Generic.List[string]] $outputHeaders = [System.Collections.Generic.List[string]]::new()
    $outputHeaders.AddRange([string[]]$generatedHeaders)
    foreach ($header in $existingHeaders) {
        if (-not $generatedHeaderLookup.ContainsKey($header)) {
            $outputHeaders.Add($header)
        }
    }

    [System.Collections.Generic.List[object]] $mergedRows = [System.Collections.Generic.List[object]]::new()
    $addedCount = 0
    $updatedCount = 0

    foreach ($generatedRow in $GeneratedRows) {
        $identity = & $getIdentity $generatedRow $generatedHeaderLookup "generated"
        $existingRow = $existingRowsByIdentity[$identity]
        $isExistingRow = $null -ne $existingRow
        if ($isExistingRow) {
            $updatedCount++
        }
        else {
            $addedCount++
        }

        $mergedRow = [ordered]@{}
        foreach ($header in $outputHeaders) {
            $generatedHeader = $generatedHeaderLookup[$header]
            $existingHeader = $existingHeaderLookup[$header]
            $preserveExistingValue = $isExistingRow -and
                $null -ne $existingHeader -and
                ($header -match "(?i)(Effect|Parameters)$" -or $null -eq $generatedHeader)

            if ($preserveExistingValue) {
                $mergedRow[$header] = $existingRow.$existingHeader
            }
            elseif ($null -ne $generatedHeader) {
                $mergedRow[$header] = $generatedRow.$generatedHeader
            }
            else {
                $mergedRow[$header] = ""
            }
        }

        $mergedRows.Add([pscustomobject]$mergedRow)
    }

    return [pscustomobject]@{
        Headers      = [string[]]$outputHeaders
        Rows         = [object[]]$mergedRows
        AddedCount   = $addedCount
        UpdatedCount = $updatedCount
        RemovedCount = $ExistingRows.Count - $updatedCount
    }
}
