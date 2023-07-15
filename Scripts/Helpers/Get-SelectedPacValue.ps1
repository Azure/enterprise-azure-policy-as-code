function Get-SelectedPacValue {
    [CmdletBinding()]
    param (
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject,

        [string] $PacSelector,
        [switch] $DeepClone
    )

    [hashtable] $selectableHashtable = @{}
    $value = $null
    if ($DeepClone) {
        $selectableHashtable = Get-DeepClone $InputObject -AsHashTable
    }
    else {
        $selectableHashtable = Get-HashtableShallowClone $InputObject
    }
    if ($selectableHashtable.ContainsKey("*")) {
        # default
        $value = $selectableHashtable["*"]
    }
    if ($selectableHashtable.ContainsKey($PacSelector)) {
        # specific, overrides default
        $value = $selectableHashtable[$PacSelector]
    }

    if ($value -is [array] -and $value.Count -le 1) {
        Write-Output $value -NoEnumerate
    }
    else {
        return $value
    }
}
