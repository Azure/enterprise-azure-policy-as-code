function Set-ExportNodeAncestors {
    [CmdletBinding()]
    param (
        [hashtable] $CurrentNode,
        [string[]] $PropertyNames,
        [int] $CurrentIndex
    )

    $PropertyName = $PropertyNames[$CurrentIndex]
    $PropertyValue = $CurrentNode.$PropertyName

    # update all ancestors
    $currentParent = $CurrentNode.parent
    while ($null -ne $currentParent) {
        $found = Merge-ExportNodeAncestors `
            -ParentNode $currentParent `
            -PropertyName $PropertyName `
            -PropertyValue $PropertyValue
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
