function Remove-GlobalNotScopes {
    [CmdletBinding()]
    param (
        $notScopes,
        $globalNotScopes
    )
    if ($null -ne $notScopes -and $notScopes.Count -gt 0) {
        if ($null -ne $globalNotScopes -and $globalNotScopes.Count -gt 0) {
            $modifiedNotScopes = [System.Collections.ArrayList]::new()
            foreach ($notScope in $notScopes) {
                $resourceGroup = $null
                if ($notScope.StartsWith("/subscriptions/") -and $notScope.Contains("/resourceGroups/")) {
                    $resourceGroupSplits = $notScope -split "/"
                    $resourceGroup = $resourceGroupSplits[-1]
                }
                $found = $false
                foreach ($globalNotScope in $globalNotScopes) {
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
            return $notScopes
        }
    }
    else {
        return $null
    }
}
