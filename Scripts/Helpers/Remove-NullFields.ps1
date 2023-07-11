function Remove-NullFields {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject
    )

    if ($null -ne $InputObject) {
        $type = $InputObject.GetType()
        $typeName = $type.Name

        if ($typeName -in @( "Hashtable", "OrderedDictionary", "OrderedHashtable" )) {
            $keys = [System.Collections.ArrayList]::new($InputObject.Keys)
            foreach ($key in $keys) {
                $value = $InputObject.$key
                if ($null -eq $value) {
                    $null = $InputObject.Remove($key)
                }
            }
            foreach ($value in $InputObject.Values) {
                $type = $value.GetType()
                $typeName = $type.Name
                if ($typeName -in @( "Object[]", "ArrayList", "Hashtable", "OrderedDictionary", "OrderedHashtable" ) -or $value -is [PSCustomObject]) {
                    Remove-NullFields $value
                }
            }
        }
        elseif ($typeName -in @( "Object[]", "ArrayList" )) {
            foreach ($value in $InputObject) {
                $type = $value.GetType()
                $typeName = $type.Name
                if ($typeName -in @( "Object[]", "ArrayList", "Hashtable", "OrderedDictionary", "OrderedHashtable") -or $value -is [PSCustomObject]) {
                    Remove-NullFields $value
                }
            }
        }
        elseif ($InputObject -is [PSCustomObject]) {
            $properties = $InputObject.psobject.properties
            $RemoveNames = [System.Collections.ArrayList]::new()
            foreach ($property in $properties) {
                $value = $property.Value
                if ($null -eq $value) {
                    $Name = $property.Name
                    $null = $RemoveNames.Add($Name)
                }
            }
            foreach ($RemoveName in $RemoveNames) {
                $null = $InputObject.psobject.properties.remove($RemoveName)
            }
            foreach ($property in $properties) {
                $value = $property.Value
                $type = $value.GetType()
                $typeName = $type.Name

                if ($typeName -in @( "Object[]", "ArrayList", "Hashtable", "OrderedDictionary", "OrderedHashtable") -or $value -is [PSCustomObject]) {
                    Remove-NullFields $value
                }
            }
        }
    }
}
