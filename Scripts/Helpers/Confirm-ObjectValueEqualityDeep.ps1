function Confirm-ObjectValueEqualityDeep {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        $object1,

        [Parameter(Position = 1)]
        $object2
    )


    if ($object1 -eq $object2) {
        return $true
    }
    else {
        if ($null -eq $object1) {
            # $object2 is not $null (always true); swap object 1 and object2, so that $object1 is always not $null
            $tempObject = $object2
            $object2 = $object1
            $object1 = $tempObject
        }
        $type1 = $object1.GetType()
        $typeName1 = $type1.Name
        $type2 = $null
        $typeName2 = "null"
        if ($null -ne $object2) {
            $type2 = $object2.GetType()
            $typeName2 = $type2.Name
        }
        if ($typeName1 -in @( "Object[]", "ArrayList") -or $typeName2 -in @( "Object[]", "ArrayList")) {
            if ($null -eq $object2) {
                return $object1.Count -eq 0
            }
            else {
                if ($typeName1 -notin @( "Object[]", "ArrayList")) {
                    # convert single element $object1 into an array
                    $object1 = @( $object1 )
                }
                if ($typeName2 -notin @( "Object[]", "ArrayList")) {
                    # convert single element $object2 into an array
                    $object2 = @( $object2 )
                }
                # both objects are now of type array or ArrayList
                if ($object1.Count -ne $object2.Count) {
                    return $false
                }
                else {
                    # iterate and recurse
                    $object2List = [System.Collections.ArrayList]::new($object2)
                    foreach ($item1 in $object1) {
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
            $dateString1 = $object1
            if ($typeName1 -eq "DateTime") {
                $dateString1 = $object1.ToString("yyyy-MM-dd")
            }
            $dateString2 = $object2
            if ($typeName2 -eq "DateTime") {
                $dateString2 = $object2.ToString("yyyy-MM-dd")
            }
            return $dateString1 -eq $dateString2
        }
        elseif ($typeName1 -eq "String" -or $typeName2 -eq "String") {
            if ($typeName1 -ne "String") {
                $object1 = $object1.ToString()
            }
            if ($null -eq $object2) {
                $object2 = ""
            }
            elseif ($typeName2 -ne "String") {
                $object2 = $object2.ToString()
            }
            return $object1 -eq $object2
        }
        elseif ($object1 -is [System.ValueType] -or $object2 -is [System.ValueType]) {
            return $false
        }
        elseif (($typeName1 -in @( "Hashtable", "OrderedDictionary", "OrderedHashtable" ) -or $object1 -is [PSCustomObject]) `
                -and ($typeName2 -in @( "null", "Hashtable", "OrderedDictionary", "OrderedHashtable" ) -or $object2 -is [PSCustomObject])) {

            if ($object1 -is [PSCustomObject]) {
                $object1 = Get-DeepClone $object1 -AsHashTable
            }

            if ($null -eq $object2) {
                $object2 = @{}
            }
            elseif ($object2 -is [PSCustomObject]) {
                $object2 = Get-DeepClone $object2 -AsHashTable
            }

            # walk both sets of keys
            $uniqueKeys = @(@($object1.Keys) + @($object2.Keys) | Sort-Object -Unique )
            foreach ($key in $uniqueKeys) {
                #recurse
                $item1 = $object1.$key
                $item2 = $object2.$key
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
