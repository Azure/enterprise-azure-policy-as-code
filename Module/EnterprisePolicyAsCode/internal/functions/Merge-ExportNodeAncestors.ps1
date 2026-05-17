function Merge-ExportNodeAncestors {
    [CmdletBinding()]
    param (
        [hashtable] $ParentNode,
        [string] $PacSelector,
        [string] $PropertyName,
        $PropertyValue
    )

    $parentClusters = $ParentNode.clusters
    if (-not $parentClusters.ContainsKey($PropertyName)) {
        $null = $parentClusters.Add($PropertyName, (ConvertTo-ArrayList $PropertyValue))
        $ParentNode[$PropertyName] = $PropertyValue
    }
    else {
        $parentCluster = $parentClusters.$PropertyName
        foreach ($clusterItem in $parentCluster) {
            $match = $false
            if ($PropertyName -eq "parameters") {
                $match = Confirm-ParametersUsageMatches $clusterItem $PropertyValue
            }
            else {
                $match = Confirm-ObjectValueEqualityDeep $clusterItem $PropertyValue
            }
            if ($match) {
                return $true
            }
        }
        $null = $parentCluster.Add($PropertyValue)
        if ($ParentNode.ContainsKey($PropertyName)) {
            $null = $ParentNode.Remove($PropertyName)
        }
    }
    return $false
}
