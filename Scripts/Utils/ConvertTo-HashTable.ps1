#Requires -PSEdition Core

function ConvertTo-HashTable {
    [CmdletBinding()]
    param
    (
        [parameter(Position = 0, ValueFromPipeline = $true)]
        [PSObject] $InputObject = $null
    )
    $hashTable = @{}
    if ($null -ne $InputObject) {
        if ($InputObject -is [hashtable]) {
            $hashTable = $InputObject.Clone()
        }
        else {
            foreach ($property in $InputObject.PSObject.Properties) {
                $hashTable[$property.Name] = $property.Value
            }
        }
    }
    return $hashTable

}
