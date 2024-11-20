function Search-AzGraphAllItems {
    param (
        [string] $Query,
        [hashtable] $ScopeSplat = @{ UseTenantScope = $true },
        $ProgressItemName,
        $ProgressIncrement = 1000
    )

    # Search-AzGraph can only return a maximum of 1000 items. Without the -First it will only return 100 items
    $body = @{
        query = $Query
        # options = @{
        #     "`$top"  = 1000
        #     "`$skip" = 0
        # }
    }
    if ($ScopeSplat.ManagementGroup) {
        $body.managementGroups = @($ScopeSplat.ManagementGroup)
    }
    elseif ($ScopeSplat.Subscription) {
        $body.subscriptions = @($ScopeSplat.Subscription)
    }
    elseif ($ScopeSplat.ManagementGroups) {
        $body.managementGroups = $ScopeSplat.ManagementGroups
    }
    elseif ($ScopeSplat.Subscriptions) {
        $body.subscriptions = $ScopeSplat.Subscriptions
    }

    [System.Collections.ArrayList] $data = [System.Collections.ArrayList]::new()

    $bodyJson = $body | ConvertTo-Json -Depth 100
    $dsi = 1
    do {
        try {
            $response = Invoke-AzRestMethod -Method POST `
                -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01" `
                -Payload $bodyJson
        }
        catch {
            Write-Warning "Recovering Data Stream Error: $_"
            $dsi++
        }
    }until($dsi -eq 5 -or ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300))
    if ($dsi -eq 5) {
        Write-Error "Failed to recover data stream after 5 attempts, information may be incomplete. Consider exiting running the script again."
    }
    elseif ($dsi -gt 1) {
        Write-Information "Data Stream recovered after $dsi attempts"
    }
    $statusCode = $response.StatusCode
    $content = $response.Content
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        Write-Error "Search-AzGraph REST error for '$Scope' $($statusCode) -- $($content)" -ErrorAction Stop
    }
    $result = $content | ConvertFrom-Json -Depth 100 -AsHashtable
    $count = $result.count

    if ($count -gt 0) {
        $null = $data.AddRange($result.data)
        if ($data.count % $ProgressIncrement -eq 0) {
            Write-Information "Retrieved $($data.count) $ProgressItemName"
        }
        while ($result.ContainsKey("`$skipToken")) {
            # More data available, $skipToken will allow the next query in this loop to continue where the last invocation ended
            $body.options = @{ "`$skipToken" = $result["`$skipToken"] }
            $bodyJson = $body | ConvertTo-Json -Depth 100
            $response = Invoke-AzRestMethod -Method POST `
                -Path "/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01" `
                -Payload $bodyJson
            $statusCode = $response.StatusCode
            $content = $response.Content
            if ($statusCode -lt 200 -or $statusCode -ge 300) {
                Write-Error "Search-AzGraph REST error for '$Scope' $($statusCode) -- $($content)" -ErrorAction Stop
            }
            $result = $content | ConvertFrom-Json -Depth 100 -AsHashtable
            $count = $result.count
            if ($count -gt 0) {
                $null = $data.AddRange($result.data)
                if ($data.count % $ProgressIncrement -eq 0) {
                    Write-Information "Retrieved $($data.count) $ProgressItemName"
                }
            }
            else {
                break
            }
        }
        $count = $data.Count
        if ($count % $ProgressIncrement -ne 0) {
            Write-Information "Retrieved $($count) $ProgressItemName"
        }
    }
    else {
        Write-Information "No $ProgressItemName found"
    }
    Write-Output $data -NoEnumerate
}
