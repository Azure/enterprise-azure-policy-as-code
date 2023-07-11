function Remove-GlobalNotScopes {
    [CmdletBinding()]
    param (
        $NotScopes,
        $GlobalNotScopes
    )
    if ($null -ne $NotScopes -and $NotScopes.Count -gt 0) {
        if ($null -ne $GlobalNotScopes -and $GlobalNotScopes.Count -gt 0) {
            $modifiedNotScopes = [System.Collections.ArrayList]::new()
            foreach ($notScope in $NotScopes) {
                $resourceGroup = $null
                if ($notScope.StartsWith("/subscriptions/") -and $notScope.Contains("/resourceGroups/")) {
                    $resourceGroupSplits = $notScope -split "/"
                    $resourceGroup = $resourceGroupSplits[-1]
                }
                $found = $false
                foreach ($globalNotScope in $GlobalNotScopes) {
                    if ($notScope -eq $globalNotScope) {
                        $found = $true
                        break
                    }
                    elseif ($globalNotScope.StartsWith("/resourceGroupPatterns/" -and $null -ne $resourceGroup)) {
                        $globalNotScopePattern = $globalNotScope -replace "/resourceGroupPatterns/"
                        if ($resourceGroup -like $globalNotScopePattern) {
                            $found = $true
                            break
                        }
                    }
                }
                if (-not $found) {
                    $null = $modifiedNotScopes.Add($notScope)
                }
            }
        }
        else {
            return $NotScopes
        }
    }
    else {
        return $null
    }
}
