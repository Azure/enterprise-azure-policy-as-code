#Requires -PSEdition Core
function Get-DeepClone {
    [cmdletbinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject,

        [switch] $AsHashTable
    )

    $json = ConvertTo-Json $InputObject -Depth 100 -Compress
    $clone = ConvertFrom-Json $json -NoEnumerate -Depth 100 -AsHashtable:$AsHashTable
    if ($InputObject -is [array]) {
        Write-Output -NoEnumerate $clone
    }
    else {
        $clone
    }
}
