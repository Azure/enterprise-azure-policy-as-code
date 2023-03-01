#Requires -PSEdition Core
function Build-NotScopes {
    param(
        [parameter(Mandatory = $True)] [hashtable] $scopeTable,
        [parameter(Mandatory = $True)] [string[]]  $scopeList,
        [parameter(Mandatory = $False)] [string[]]  $notScopeIn = @()
    )

    $scopeCollection = @()
    foreach ($scope in $scopeList) {
        if ($scopeTable.ContainsKey($scope)) {
            if ($scope.Contains("/resourceGroups/")) {
                $scopeCollection += @{
                    scope    = "$scope"
                    notScope = @()
                }
            }
            else {
                $notScopes = [System.Collections.ArrayList]::new()
                $scopeEntry = $scopeTable.$scope
                $scopeChildren = $scopeEntry.childrenList
                $scopeResourceGroups = $scopeEntry.resourceGroups
                foreach ($notScope in $notScopeIn) {
                    if ($notScope.StartsWith("/resourceGroupPatterns/")) {
                        $pattern = $notScope -replace "/resourceGroupPatterns/", "/subscriptions/*/resourceGroups/"
                        foreach ($id in $scopeResourceGroups.Keys) {
                            if ($id -like $pattern) {
                                $null = $notScopes.Add($id)
                            }
                        }
                    }
                    elseif ($scopeChildren.ContainsKey($notScope)) {
                        $null = $notScopes.Add($notScope)
                    }
                }
                $scopeCollection += @{
                    scope    = "$scope"
                    notScope = $notScopes.ToArray()
                }
            }
        }
        else {
            Write-Error "Scope '$scope' not found in environment" -ErrorAction Stop
        }
    }

    Write-Output $scopeCollection -NoEnumerate
}
