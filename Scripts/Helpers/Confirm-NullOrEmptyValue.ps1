function Confirm-NullOrEmptyValue {
    [CmdletBinding()]
    param (
        $inputObject,
        $nullOnly = $false
    )

    if ($null -eq $inputObject) {
        return $true
    }
    elseif (!$nullOnly) {
        $type = $inputObject.GetType()
        $typeName = $type.Name
        if ($typeName -in @( "String" )) {
            return "" -eq $inputObject
        }
        elseif ($typeName -in @( "Object[]", "ArrayList" )) {
            return $inputObject.Count -eq 0
        }
        elseif ($typeName -in @( "Hashtable", "OrderedDictionary", "OrderedHashtable" )) {
            return $inputObject.Count -eq 0
        }
        elseif ($typeName -ne "DateTimeS" -and $inputObject -is [PSCustomObject]) {
            $properties = $inputObject | Get-Member -MemberType Properties
            return $properties.Count -eq 0
        }
        else {
            return $false
        }
    }
}
