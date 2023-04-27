function Search-AzGraphAllItems {
    param (
        [string] $query,
        [hashtable] $scope,
        $progressItemName
    )

    [System.Collections.ArrayList] $data = [System.Collections.ArrayList]::new()
    # Search-AzGraph can only return a maximum of 1000 items. Without the -First it will only return 100 items
    $result = Search-AzGraph $query -First 1000 @scope
    $null = $data.AddRange($result.Data)
    while ($null -ne $result.SkipToken) {
        # More data available, SkipToken will allow the next query in this loop to continue where the last invocation ended
        Write-Information "Retrieved $($data.Count) $progressItemName"
        $result = Search-AzGraph $query -First 1000 -SkipToken $result.SkipToken  @scope
        $null = $data.AddRange($result.Data)
    }
    Write-Information "Retrieved $($data.Count) $progressItemName"
    return $data
}
