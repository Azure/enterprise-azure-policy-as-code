function Merge-ExportNodeAncestors {
    [CmdletBinding()]
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string] $propertyName,
        $propertyValue
    )

    $parentClusters = $parentNode.clusters
    if (-not $parentClusters.ContainsKey($propertyName)) {
        $null = $parentClusters.Add($propertyName, (ConvertTo-ArrayList $propertyValue))
        $parentNode[$propertyName] = $propertyValue
    }
    else {
        $parentCluster = $parentClusters.$propertyName
        foreach ($clusterItem in $parentCluster) {
            $match = Confirm-ObjectValueEqualityDeep $clusterItem $propertyValue
            if ($match) {
                return $true
            }
        }
        $null = $parentCluster.Add($propertyValue)
        if ($parentNode.ContainsKey($propertyName)) {
            $null = $parentNode.Remove($propertyName)
        }
    }
    return $false
}
