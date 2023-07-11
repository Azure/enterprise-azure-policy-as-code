function Set-ExportNode {
    [CmdletBinding()]
    param (
        [hashtable] $ParentNode,
        [string] $PacSelector,
        [string[]] $PropertyNames,
        [hashtable] $PropertiesList,
        [int] $CurrentIndex
    )

    $PropertyName = $PropertyNames[$CurrentIndex]
    $PropertyValue = $PropertiesList.$PropertyName

    # process this list entry
    $thisNode = Merge-ExportNodeChild `
        -ParentNode $ParentNode `
        -PacSelector $PacSelector `
        -PropertyName $PropertyName `
        -PropertyValue $PropertyValue

    # recursively call Set-ClusterNode to create remaining descendants
    $CurrentIndex++
    if ($CurrentIndex -lt $PropertyNames.Count) {
        Set-ExportNode `
            -ParentNode $thisNode `
            -PacSelector $PacSelector `
            -PropertyNames $PropertyNames `
            -PropertiesList $PropertiesList `
            -CurrentIndex $CurrentIndex
    }
}
