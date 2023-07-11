function Merge-ExportNodeChild {
    [CmdletBinding()]
    param (
        [hashtable] $ParentNode,
        [string] $PacSelector,
        [string] $PropertyName,
        $PropertyValue
    )

    $parentChildren = $ParentNode.children
    $match = $false
    foreach ($child in $parentChildren) {
        $childPropertyValue = $child.$PropertyName
        switch ($PropertyName) {
            parameters {
                # temp for debugging, default will handle later
                $match = Confirm-ObjectValueEqualityDeep $childPropertyValue $PropertyValue
                # if (!$match) {
                #     $test = Confirm-ObjectValueEqualityDeep $childPropertyValue $PropertyValue
                # }
            }
            additionalRoleAssignments {
                if ($childPropertyValue.ContainsKey($PacSelector)) {
                    $match = Confirm-ObjectValueEqualityDeep $childPropertyValue.$PacSelector $PropertyValue
                }
                else {
                    $match = $true
                    $null = $childPropertyValue.Add($PacSelector, $PropertyValue)
                }
                break
            }
            identityEntry {
                if ($childPropertyValue.ContainsKey($PacSelector)) {
                    $match = Confirm-ObjectValueEqualityDeep $childPropertyValue.$PacSelector $PropertyValue
                }
                else {
                    $match = $true
                    $null = $childPropertyValue.Add($PacSelector, $PropertyValue)
                }
                break
            }
            notScopes {
                if ($childPropertyValue.ContainsKey($PacSelector)) {
                    $NotScopes = $childPropertyValue.$PacSelector
                    $match = Confirm-ObjectValueEqualityDeep $NotScopes $PropertyValue
                }
                else {
                    $match = $true
                    $NotScopes = $PropertyValue
                    $null = $childPropertyValue.Add($PacSelector, $NotScopes)
                }
                break
            }
            scopes {
                $match = $true
                if ($childPropertyValue.ContainsKey($PacSelector)) {
                    $Scopes = $childPropertyValue.$PacSelector
                    if ($Scopes -notcontains $PropertyValue) {
                        $null = $Scopes.Add($PropertyValue)
                    }
                }
                else {
                    $Scopes = ConvertTo-ArrayList $PropertyValue
                    $null = $childPropertyValue.Add($PacSelector, $Scopes)
                }
                break
            }
            default {
                $match = Confirm-ObjectValueEqualityDeep $childPropertyValue $PropertyValue
                break
            }
        }
        if ($match) {
            # existing cluster
            return $child
        }
    }

    $child = New-ExportNode `
        -ParentNode $ParentNode `
        -PacSelector $PacSelector `
        -PropertyName $PropertyName `
        -PropertyValue $PropertyValue
    $null = $parentChildren.Add($child)

    return $child
}
