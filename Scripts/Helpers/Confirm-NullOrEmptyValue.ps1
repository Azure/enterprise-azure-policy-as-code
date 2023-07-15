function Confirm-NullOrEmptyValue {
    [CmdletBinding()]
    param (
        $InputObject,
        $NullOnly = $false
    )

    if ($null -eq $InputObject) {
        return $true
    }
    elseif (!$NullOnly) {
        $type = $InputObject.GetType()
        $typeName = $type.Name
        if ($typeName -in @( "String" )) {
            return "" -eq $InputObject
        }
        elseif ($typeName -in @( "Object[]", "ArrayList" )) {
            return $InputObject.Count -eq 0
        }
        elseif ($typeName -in @( "Hashtable", "OrderedDictionary", "OrderedHashtable" )) {
            return $InputObject.Count -eq 0
        }
        elseif ($typeName -ne "DateTimeS" -and $InputObject -is [PSCustomObject]) {
            $properties = $InputObject | Get-Member -MemberType Properties
            return $properties.Count -eq 0
        }
        else {
            return $false
        }
    }
}
