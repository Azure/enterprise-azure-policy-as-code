function Set-ExportNodeAncestors {
    [CmdletBinding()]
    param (
        [hashtable] $currentNode,
        [string[]] $propertyNames,
        [int] $currentIndex
    )

    $propertyName = $propertyNames[$currentIndex]
    $propertyValue = $currentNode.$propertyName

    # update all ancestors
    $currentParent = $currentNode.parent
    while ($null -ne $currentParent) {
        $found = Merge-ExportNodeAncestors `
            -parentNode $currentParent `
            -propertyName $propertyName `
            -propertyValue $propertyValue
        if ($found) {
            break
        }
        $currentParent = $currentParent.parent
    }

    # recursively call Set-ExportNodeAncestors to process remaining descendants
    $currentIndex++
    foreach ($child in $currentNode.children) {
        Set-ExportNodeAncestors `
            -currentNode $child `
            -propertyNames $propertyNames `
            -currentIndex $currentIndex
    }
}
