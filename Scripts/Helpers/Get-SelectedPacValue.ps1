function Get-SelectedPacValue {
    [CmdletBinding()]
    param (
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject,

        [string] $pacSelector,
        [switch] $deepClone
    )

    [hashtable] $selectableHashtable = @{}
    $value = $null
    if ($deepClone) {
        $selectableHashtable = Get-DeepClone $InputObject -AsHashTable
    }
    else {
        $selectableHashtable = Get-HashtableShallowClone $InputObject
    }
    if ($selectableHashtable.ContainsKey("*")) {
        # default
        $value = $selectableHashtable["*"]
    }
    if ($selectableHashtable.ContainsKey($pacSelector)) {
        # specific, overrides default
        $value = $selectableHashtable[$pacSelector]
    }

    if ($value -is [array] -and $value.Count -le 1) {
        Write-Output $value -NoEnumerate
    }
    else {
        return $value
    }
}
