#Requires -PSEdition Core
function Get-HashtableShallowClone {
    [cmdletbinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject
    )

    $clone = @{}
    if ($null -ne $InputObject) {
        if ($InputObject -isnot [hashtable]) {
            $clone = ConvertTo-HashTable $InputObject
        }
        else {
            $clone = $InputObject.Clone()
        }
    }
    return $clone
}
