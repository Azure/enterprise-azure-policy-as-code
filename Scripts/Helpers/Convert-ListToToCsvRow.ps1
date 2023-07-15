function Convert-ListToToCsvRow {
    param (
        [System.Collections.IEnumerable] $List
    )

    [System.Text.StringBuilder] $rowText = [System.Text.StringBuilder]::new()
    $comma = ""
    foreach ($item in $List) {
        if ($item -is [hashtable] -or $parameter -is [PSCustomObject]) {
            $item = "object"
        }
        $itemEscaped = $item -replace "`"", "`"`""
        $null = $rowText.Append("$comma`"$itemEscaped`"")
        $comma = ","
    }
    $rowString = $rowText.ToString()
    return $rowString
}
