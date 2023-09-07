function    ConvertTo-HashTable {
    [CmdletBinding()]
    param
    (
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject = $null
    )

    [hashtable] $hashTable = @{}
    if ($null -ne $InputObject) {
        if ($InputObject -is [System.Collections.IDictionary]) {
            if ($InputObject -is [hashtable]) {
                return $InputObject
            }
            else {
                foreach ($key in $InputObject.Keys) {
                    $null = $hashTable[$key] = $InputObject[$key]
                }
            }
        }
        elseif ($InputObject.psobject.Properties) {
            foreach ($property in $InputObject.psobject.Properties) {
                $hashTable[$property.Name] = $property.Value
            }
        }
    }
    return $hashTable

}
