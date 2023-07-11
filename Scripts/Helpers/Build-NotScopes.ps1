#Requires -PSEdition Core
function Build-NotScopes {
    param(
        [parameter(Mandatory = $True)] [hashtable] $ScopeTable,
        [parameter(Mandatory = $True)] [string[]]  $ScopeList,
        [parameter(Mandatory = $False)] [string[]]  $NotScopeIn = @()
    )

    $ScopeCollection = @()
    foreach ($Scope in $ScopeList) {
        if ($ScopeTable.ContainsKey($Scope)) {
            if ($Scope.Contains("/resourceGroups/")) {
                $ScopeCollection += @{
                    scope    = "$Scope"
                    notScope = @()
                }
            }
            else {
                $NotScopes = [System.Collections.ArrayList]::new()
                $ScopeEntry = $ScopeTable.$Scope
                $ScopeChildren = $ScopeEntry.childrenList
                $ScopeResourceGroups = $ScopeEntry.resourceGroups
                foreach ($notScope in $NotScopeIn) {
                    if ($notScope.StartsWith("/resourceGroupPatterns/")) {
                        $pattern = $notScope -replace "/resourceGroupPatterns/", "/subscriptions/*/resourceGroups/"
                        foreach ($Id in $ScopeResourceGroups.Keys) {
                            if ($Id -like $pattern) {
                                $null = $NotScopes.Add($Id)
                            }
                        }
                    }
                    elseif ($ScopeChildren.ContainsKey($notScope)) {
                        $null = $NotScopes.Add($notScope)
                    }
                }
                $ScopeCollection += @{
                    scope    = "$Scope"
                    notScope = $NotScopes.ToArray()
                }
            }
        }
        else {
            Write-Error "Scope '$Scope' not found in environment" -ErrorAction Stop
        }
    }

    Write-Output $ScopeCollection -NoEnumerate
}
