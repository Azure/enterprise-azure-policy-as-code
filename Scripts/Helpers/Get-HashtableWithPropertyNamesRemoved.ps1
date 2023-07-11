function Get-HashtableWithPropertyNamesRemoved {
    [CmdletBinding()]
    param(
        $Object,
        $PropertyNames
    )

    $ObjectClone = $Object
    if ($Object -is [System.Collections.IDictionary]) {
        $ObjectClone1 = $Object.Clone()
        if ($PropertyNames -is [System.Collections.IList]) {
            foreach ($PropertyName in $PropertyNames) {
                $ObjectClone1.Remove($PropertyName)
            }
        }
        else {
            $ObjectClone1.Remove($PropertyNames)
        }
        $ObjectClone = @{}
        foreach ($key in $ObjectClone1.Keys) {
            $value = $ObjectClone1.$key
            $newValue = Get-HashtableWithPropertyNamesRemoved -Object $value -property $PropertyNames
            $null = $ObjectClone.Add($key, $newValue)
        }
        return $ObjectClone
    }
    elseif ($Object -is [System.Collections.IList]) {
        $ObjectClone = [System.Collections.ArrayList]::new()
        foreach ($item in $Object) {
            $newValue = Get-HashtableWithPropertyNamesRemoved -Object $item -property $PropertyNames
            $null = $ObjectClone.Add($newValue)
        }
        Write-Output $ObjectClone -NoEnumerate
    }
    else {
        return $ObjectClone
    }
}
