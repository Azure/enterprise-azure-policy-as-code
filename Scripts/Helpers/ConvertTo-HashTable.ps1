function ConvertTo-HashTable {
    [CmdletBinding()]
    param
    (
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject = $null
    )

    [hashtable] $hashTable = @{}
    if ($null -ne $InputObject) {
        if ($null -ne $InputObject.Keys -and $null -ne $InputObject.Values) {
            foreach ($key in $InputObject.Keys) {
                try {
                    $null = $hashTable.Add($key, $InputObject[$key])
                }
                catch {
                    Write-Information $key <#Do this if a terminating exception happens#>
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
