function Get-HashtableWithPropertyNamesRemoved {
    [CmdletBinding()]
    param(
        $object,
        $propertyNames
    )

    $objectClone = $object
    if ($object -is [System.Collections.IDictionary]) {
        $objectClone1 = $object.Clone()
        if ($propertyNames -is [System.Collections.IList]) {
            foreach ($propertyName in $propertyNames) {
                $objectClone1.Remove($propertyName)
            }
        }
        else {
            $objectClone1.Remove($propertyNames)
        }
        $objectClone = @{}
        foreach ($key in $objectClone1.Keys) {
            $value = $objectClone1.$key
            $newValue = Get-HashtableWithPropertyNamesRemoved -object $value -property $propertyNames
            $null = $objectClone.Add($key, $newValue)
        }
        return $objectClone
    }
    elseif ($object -is [System.Collections.IList]) {
        $objectClone = [System.Collections.ArrayList]::new()
        foreach ($item in $object) {
            $newValue = Get-HashtableWithPropertyNamesRemoved -object $item -property $propertyNames
            $null = $objectClone.Add($newValue)
        }
        Write-Output $objectClone -NoEnumerate
    }
    else {
        return $objectClone
    }
}
