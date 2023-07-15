function Confirm-ObjectValueEqualityDeep {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        $Object1,

        [Parameter(Position = 1)]
        $Object2
    )


    if ($Object1 -eq $Object2) {
        return $true
    }
    else {
        if ($null -eq $Object1) {
            # $Object2 is not $null (always true); swap object 1 and object2, so that $Object1 is always not $null
            $tempObject = $Object2
            $Object2 = $Object1
            $Object1 = $tempObject
        }
        $type1 = $Object1.GetType()
        $typeName1 = $type1.Name
        $type2 = $null
        $typeName2 = "null"
        if ($null -ne $Object2) {
            $type2 = $Object2.GetType()
            $typeName2 = $type2.Name
        }
        if ($typeName1 -in @( "Object[]", "ArrayList") -or $typeName2 -in @( "Object[]", "ArrayList")) {
            if ($null -eq $Object2) {
                return $Object1.Count -eq 0
            }
            else {
                if ($typeName1 -notin @( "Object[]", "ArrayList")) {
                    # convert single element $Object1 into an array
                    $Object1 = @( $Object1 )
                }
                if ($typeName2 -notin @( "Object[]", "ArrayList")) {
                    # convert single element $Object2 into an array
                    $Object2 = @( $Object2 )
                }
                # both objects are now of type array or ArrayList
                if ($Object1.Count -ne $Object2.Count) {
                    return $false
                }
                else {
                    # iterate and recurse
                    $object2List = [System.Collections.ArrayList]::new($Object2)
                    foreach ($item1 in $Object1) {
                        $foundMatch = $false
                        for ($i = 0; $i -lt $object2List.Count; $i++) {
                            $item2 = $object2List[$i]
                            if ($item1 -eq $item2 -or (Confirm-ObjectValueEqualityDeep $item1 $item2)) {
                                $foundMatch = $true
                                $null = $object2List.RemoveAt($i)
                                break
                            }
                        }
                        if (!$foundMatch) {
                            return $false
                        }
                    }
                    return $true
                }
            }
        }
        elseif ($typeName1 -eq "DateTime" -or $typeName1 -eq "DateTime") {
            $dateString1 = $Object1
            if ($typeName1 -eq "DateTime") {
                $dateString1 = $Object1.ToString("yyyy-MM-dd")
            }
            $dateString2 = $Object2
            if ($typeName2 -eq "DateTime") {
                $dateString2 = $Object2.ToString("yyyy-MM-dd")
            }
            return $dateString1 -eq $dateString2
        }
        elseif ($typeName1 -eq "String" -or $typeName2 -eq "String") {
            if ($typeName1 -ne "String") {
                $Object1 = $Object1.ToString()
            }
            if ($null -eq $Object2) {
                $Object2 = ""
            }
            elseif ($typeName2 -ne "String") {
                $Object2 = $Object2.ToString()
            }
            return $Object1 -eq $Object2
        }
        elseif ($Object1 -is [System.ValueType] -or $Object2 -is [System.ValueType]) {
            return $false
        }
        elseif (($typeName1 -in @( "Hashtable", "OrderedDictionary", "OrderedHashtable" ) -or $Object1 -is [PSCustomObject]) `
                -and ($typeName2 -in @( "null", "Hashtable", "OrderedDictionary", "OrderedHashtable" ) -or $Object2 -is [PSCustomObject])) {

            if ($Object1 -is [PSCustomObject]) {
                $Object1 = Get-DeepClone $Object1 -AsHashTable
            }

            if ($null -eq $Object2) {
                $Object2 = @{}
            }
            elseif ($Object2 -is [PSCustomObject]) {
                $Object2 = Get-DeepClone $Object2 -AsHashTable
            }

            # walk both sets of keys
            $uniqueKeys = @(@($Object1.Keys) + @($Object2.Keys) | Sort-Object -Unique )
            foreach ($key in $uniqueKeys) {
                #recurse
                $item1 = $Object1.$key
                $item2 = $Object2.$key
                if ($item1 -ne $item2 -and !(Confirm-ObjectValueEqualityDeep $item1 $item2)) {
                    return $false
                }
            }
            return $true
        }
        else {
            # equality of other types handled in the then clause of the outer else clause
            return $false
        }
    }
}
