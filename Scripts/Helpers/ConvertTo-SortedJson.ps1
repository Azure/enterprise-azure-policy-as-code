function ConvertTo-SortedJson {
    param (
        [parameter(Position = 0)]
        $InputObject
    )

    # ConvertTo-Json writes hashtable keys in an arbitrary order; sort them so the same value always gives the same text
    function Get-SortedValue($Value) {
        if ($Value -is [System.Collections.IDictionary]) {
            $sorted = [ordered]@{}
            foreach ($key in ($Value.Keys | Sort-Object)) {
                $sorted[$key] = Get-SortedValue $Value[$key]
            }
            return $sorted
        }
        if ($Value -is [System.Collections.IList]) {
            return , @(foreach ($item in $Value) { Get-SortedValue $item })
        }
        return $Value
    }

    return ConvertTo-Json (Get-SortedValue $InputObject) -Depth 100 -Compress
}
