function Get-HashtableWithPropertyNamesRemoved {
    [CmdletBinding()]
    param(
        $Object,
        $PropertyNames
    )

    $objectClone = $Object
    if ($Object -is [System.Collections.IDictionary]) {
        $objectClone1 = $Object.Clone()
        if ($PropertyNames -is [System.Collections.IList]) {
            foreach ($propertyName in $PropertyNames) {
                $objectClone1.Remove($propertyName)
            }
        }
        else {
            $objectClone1.Remove($PropertyNames)
        }
        $objectClone = @{}
        foreach ($key in $objectClone1.Keys) {
            $value = $objectClone1.$key
            $newValue = Get-HashtableWithPropertyNamesRemoved -Object $value -property $PropertyNames
            $null = $objectClone.Add($key, $newValue)
        }
        return $objectClone
    }
    elseif ($Object -is [System.Collections.IList]) {
        $objectClone = [System.Collections.ArrayList]::new()
        foreach ($item in $Object) {
            $newValue = Get-HashtableWithPropertyNamesRemoved -Object $item -property $PropertyNames
            $null = $objectClone.Add($newValue)
        }
        Write-Output $objectClone -NoEnumerate
    }
    else {
        return $objectClone
    }
}
