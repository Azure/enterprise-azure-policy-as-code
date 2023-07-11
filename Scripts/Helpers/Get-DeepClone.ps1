function Get-DeepClone {
    [CmdletBinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject,

        [switch] $AsHashtable
    )

    if ($null -ne $InputObject) {
        $json = ConvertTo-Json $InputObject -Depth 100 -Compress
        $clone = ConvertFrom-Json $json -NoEnumerate -Depth 100 -AsHashtable:$AsHashtable
        if ($InputObject -is [array]) {
            Write-Output -NoEnumerate $clone
        }
        else {
            return $clone
        }
    }
    elseif ($AsHashtable) {
        return @{}
    }
    else {
        return $null
    }
}
