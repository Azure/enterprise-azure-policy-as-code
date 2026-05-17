function Confirm-NullOrEmptyValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $InputObject = $null,

        [Parameter(Mandatory = $false)]
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
        elseif ($typeName -ne "DateTime" -and $InputObject -is [PSCustomObject]) {
            $properties = $InputObject | Get-Member -MemberType Properties
            return $properties.Count -eq 0
        }
        else {
            return $false
        }
    }
}
