function Set-ExportNode {
    [CmdletBinding()]
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string[]] $propertyNames,
        [hashtable] $propertiesList,
        [int] $currentIndex
    )

    $propertyName = $propertyNames[$currentIndex]
    $propertyValue = $propertiesList.$propertyName

    # process this list entry
    $thisNode = Merge-ExportNodeChild `
        -parentNode $parentNode `
        -pacSelector $pacSelector `
        -propertyName $propertyName `
        -propertyValue $propertyValue

    # recursively call Set-ClusterNode to create remaining descendants
    $currentIndex++
    if ($currentIndex -lt $propertyNames.Count) {
        Set-ExportNode `
            -parentNode $thisNode `
            -pacSelector $pacSelector `
            -propertyNames $propertyNames `
            -propertiesList $propertiesList `
            -currentIndex $currentIndex
    }
}
