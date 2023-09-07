function Get-DeepClone {
    [CmdletBinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject,

        [switch] $AsHashTable
    )

    if ($null -ne $InputObject) {
        $json = ConvertTo-Json $InputObject -Depth 100 -Compress
        $clone = ConvertFrom-Json $json -NoEnumerate -Depth 100 -AsHashTable:$AsHashTable
        if ($InputObject -is [System.Collections.IList]) {
            Write-Output -NoEnumerate $clone
        }
        else {
            return $clone
        }
    }
    elseif ($AsHashTable) {
        return @{}
    }
    else {
        return $null
    }
}
