function Search-AzGraphAllItems {
    param (
        [string] $Query,
        [hashtable] $ScopeSplat = @{ UseTenantScope = $true },
        $ProgressItemName,
        $ProgressIncrement = 1000
    )

    [System.Collections.ArrayList] $data = [System.Collections.ArrayList]::new()
    # Search-AzGraph can only return a maximum of 1000 items. Without the -First it will only return 100 items
    $result = Search-AzGraph $Query -First 1000 @ScopeSplat
    $null = $data.AddRange($result.Data)
    while ($null -ne $result.SkipToken) {
        # More data available, SkipToken will allow the next query in this loop to continue where the last invocation ended
        $count = $data.Count
        if ($count % $ProgressIncrement -eq 0) {
            Write-Information "Retrieved $count $ProgressItemName"
        }
        $result = Search-AzGraph $Query -First 1000 -SkipToken $result.SkipToken @ScopeSplat
        $null = $data.AddRange($result.Data)
    }
    $count = $data.Count
    if ($count % $ProgressIncrement -ne 0) {
        Write-Information "Retrieved $($count) $ProgressItemName"
    }
    Write-Output $data -NoEnumerate
}
