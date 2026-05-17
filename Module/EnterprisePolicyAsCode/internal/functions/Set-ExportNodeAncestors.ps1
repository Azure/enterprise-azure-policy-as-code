function Set-ExportNodeAncestors {
    [CmdletBinding()]
    param (
        [hashtable] $CurrentNode,
        [string[]] $PropertyNames,
        [int] $CurrentIndex
    )

    $propertyName = $PropertyNames[$CurrentIndex]
    $propertyValue = $CurrentNode.$propertyName

    # update all ancestors
    $currentParent = $CurrentNode.parent
    while ($null -ne $currentParent) {
        $found = Merge-ExportNodeAncestors `
            -ParentNode $currentParent `
            -PropertyName $propertyName `
            -PropertyValue $propertyValue
        if ($found) {
            break
        }
        $currentParent = $currentParent.parent
    }

    # recursively call Set-ExportNodeAncestors to process remaining descendants
    $CurrentIndex++
    foreach ($child in $CurrentNode.children) {
        Set-ExportNodeAncestors `
            -CurrentNode $child `
            -PropertyNames $PropertyNames `
            -CurrentIndex $CurrentIndex
    }
}
