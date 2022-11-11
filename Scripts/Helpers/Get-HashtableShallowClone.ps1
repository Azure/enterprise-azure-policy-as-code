#Requires -PSEdition Core
function Get-HashtableShallowClone {
    [cmdletbinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject
    )

    if ($null -ne $InputObject) {
        if ($InputObject -isnot [hashtable]) {
            return ConvertTo-HashTable $InputObject
        }
        else {
            return $InputObject.Clone()
        }
    }
    else {
        return @{}
    }
}
