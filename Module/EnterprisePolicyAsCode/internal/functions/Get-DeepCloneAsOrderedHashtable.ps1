function Get-DeepCloneAsOrderedHashtable {
    [CmdletBinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject
    )

    $clone = $null
    # only support deep cloning to hashtable
    if ($null -ne $InputObject) {
        $json = ConvertTo-Json $InputObject -Depth 100 -Compress
        $clone = ConvertFrom-Json $json -NoEnumerate -Depth 100 -AsHashTable
    }

    if ($clone -is [System.Collections.IList]) {
        Write-Output $clone -NoEnumerate
    }
    else {
        Write-Output $clone
    }
}
