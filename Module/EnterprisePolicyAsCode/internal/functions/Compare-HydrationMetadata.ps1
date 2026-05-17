function Compare-HydrationMetadata {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $oldKeys = @{},
        [Parameter(Mandatory = $false)]
        $newKeys = @{}
    )

    $metadataComparison = [ordered]@{
        ValueDifferences = @{}
        OnlyInOld        = @()
        OnlyInNew        = @()
    }

    # Compare values for matching keys
    $valueDifferences = @()
    foreach ($key in ($oldKeys.keys + $newKeys.keys | Select-Object -Unique)) {
        $oldValue = $oldKeys[$key]
        $newValue = $newKeys[$key]
        if ($oldValue -ne $newValue) {
        $valueDifferences += `
            [PSCustomObject]@{
                Key      = $key
                OldValue = $oldValue
                NewValue = $newValue
            }
        }
    }

    # Find keys only in old or only in new
    $onlyInOld = $oldKeys | Where-Object { $_ -notin $newKeys }
    $onlyInNew = $newKeys | Where-Object { $_ -notin $oldKeys }

    $metadataComparison = [ordered]@{
        ValueDifferences = $valueDifferences
        OnlyInOld        = $onlyInOld
        OnlyInNew        = $onlyInNew
    }

    return $metadataComparison
}