#Requires -PSEdition Core

function Get-FilteredHashTable {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [pscustomobject] $Object,

        [Parameter()]
        [string] $Filter = $null

    )

    [hashtable] $result = @{}
    [hashtable] $inHt = @{}
    if ($null -ne $Object) {
        if ($Object -is [hashtable]) {
            $inHt = $Object
        }
        else {
            $inHt = $Object | ConvertTo-HashTable
        }
        if ($null -eq $Filter -or $Filter -eq "") {
            $result = $inHt
        }
        else {
            $transforms = $Filter.Split()
            # ignore an empty splat
            foreach ($transform in $transforms) {
                $splits = $transform.Split("/")
                $selector = $splits[0]
                if ($inHt.ContainsKey($selector)) {
                    $entry = $inHt[$selector]
                    $value = $entry
                    if ($entry -is [array] -or $entry -is [PSCustomObject] -or $entry -is [hashtable]) {
                        $json = ConvertTo-Json $entry -Depth 100 -Compress
                        $value = $json
                    }
                    switch ($splits.Length) {
                        1 { $result.Add($selector, $value); break } #
                        2 { $result.Add($splits[1], $value); break }
                        Default { throw "inHtTransform has too menay parts ""$transform""" }
                    }
                }
            }
        }
    }
    return $result
}