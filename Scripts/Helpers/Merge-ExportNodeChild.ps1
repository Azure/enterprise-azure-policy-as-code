function Merge-ExportNodeChild {
    [CmdletBinding()]
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string] $propertyName,
        $propertyValue
    )

    $parentChildren = $parentNode.children
    $match = $false
    foreach ($child in $parentChildren) {
        $childPropertyValue = $child.$propertyName
        switch ($propertyName) {
            parameters {
                # temp for debugging, default will handle later
                $match = Confirm-ObjectValueEqualityDeep $childPropertyValue $propertyValue
                # if (!$match) {
                #     $test = Confirm-ObjectValueEqualityDeep $childPropertyValue $propertyValue
                # }
            }
            additionalRoleAssignments {
                if ($childPropertyValue.ContainsKey($pacSelector)) {
                    $match = Confirm-ObjectValueEqualityDeep $childPropertyValue.$pacSelector $propertyValue
                }
                else {
                    $match = $true
                    $null = $childPropertyValue.Add($pacSelector, $propertyValue)
                }
                break
            }
            identityEntry {
                if ($childPropertyValue.ContainsKey($pacSelector)) {
                    $match = Confirm-ObjectValueEqualityDeep $childPropertyValue.$pacSelector $propertyValue
                }
                else {
                    $match = $true
                    $null = $childPropertyValue.Add($pacSelector, $propertyValue)
                }
                break
            }
            notScopes {
                if ($childPropertyValue.ContainsKey($pacSelector)) {
                    $notScopes = $childPropertyValue.$pacSelector
                    $match = Confirm-ObjectValueEqualityDeep $notScopes $propertyValue
                }
                else {
                    $match = $true
                    $notScopes = $propertyValue
                    $null = $childPropertyValue.Add($pacSelector, $notScopes)
                }
                break
            }
            scopes {
                $match = $true
                if ($childPropertyValue.ContainsKey($pacSelector)) {
                    $scopes = $childPropertyValue.$pacSelector
                    if ($scopes -notcontains $propertyValue) {
                        $null = $scopes.Add($propertyValue)
                    }
                }
                else {
                    $scopes = ConvertTo-ArrayList $propertyValue
                    $null = $childPropertyValue.Add($pacSelector, $scopes)
                }
                break
            }
            default {
                $match = Confirm-ObjectValueEqualityDeep $childPropertyValue $propertyValue
                break
            }
        }
        if ($match) {
            # existing cluster
            return $child
        }
    }

    $child = New-ExportNode `
        -parentNode $parentNode `
        -pacSelector $pacSelector `
        -propertyName $propertyName `
        -propertyValue $propertyValue
    $null = $parentChildren.Add($child)

    return $child
}
