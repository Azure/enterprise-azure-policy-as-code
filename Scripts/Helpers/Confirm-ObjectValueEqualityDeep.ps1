function Confirm-ObjectValueEqualityDeep {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        $Object1,

        [Parameter(Position = 1)]
        $Object2,

        [switch] $HandleRandomOrderArray,
        [switch] $CaseInsensitiveKeys
    )


    if ($Object1 -eq $Object2) {
        # $Object1 and $Object2 are equal (includes both $null)
        return $true
    }
    elseif ($null -eq $Object1 -or $null -eq $Object2) {
        # $Object1 and $Object2 are not equal, but one of them is $null
        if ($null -eq $Object1) {
            # $Object1 is $null, swap $Object1 and $Object2 to ensure that Object1 (the old Object2) is not $null and Object2 (the old Object1) is $null (setting it to $null is ommited because it is not used in the subsequent code)
            $Object1 = $Object2
        }
        if ($Object1 -is [System.Collections.IList]) {
            # $Object1 is an array or ArrayList, if it is empty treat it as $null and therefore equal to Object2
            return $Object1.Count -eq 0
        }
        elseif ($Object1 -is [System.Collections.IDictionary]) {
            # $Object1 is a hashtable, if it is empty treat it as $null and therefore equal to Object2
            return $Object1.Count -eq 0
        }
        elseif ($Object1 -is [string]) {
            # $Object1 is a string, if it is empty or only conatins whitespace treat it as $null and therefore equal to Object2
            return [string]::IsNullOrWhiteSpace($Object1)
        }
        else {
            # $Object1 has something else and not null and therefore not equal to Object2
            return $false
        }
    }
    else {
        $type1 = $Object1.GetType()
        $typeName1 = $type1.Name
        $type2 = $Object2.GetType()
        $typeName2 = $type2.Name
        if ($Object1 -is [System.Collections.Ilist] -or $Object2 -is [System.Collections.Ilist]) {
            # $Object1 or $Object2 is an array or ArrayList
            if ($Object1 -isnot [System.Collections.Ilist]) {
                $Object1 = @($Object1)
            }
            elseif ($Object2 -isnot [System.Collections.Ilist]) {
                $Object2 = @($Object2)
            }
            if ($Object1.Count -ne $Object2.Count) {
                return $false
            }
            else {
                # iterate and recurse
                if ($HandleRandomOrderArray) {
                    $object2List = [System.Collections.ArrayList]::new($Object2)
                    foreach ($item1 in $Object1) {
                        # iterate through Object1 and find a match in Object2
                        $foundMatch = $false
                        for ($i = 0; $i -lt $object2List.Count; $i++) {
                            $item2 = $object2List[$i]
                            if ($item1 -eq $item2 -or (Confirm-ObjectValueEqualityDeep $item1 $item2 -HandleRandomOrderArray -CaseInsensitiveKeys:$CaseInsensitiveKeys)) {
                                # if either the array item values are equal or a deep inspection shows equal, continue to the next item by:
                                #   1. Setting $foundMatch to $true
                                #   2. Remove the matching item from the Object2 list, therefore reducing the computing complexity of the next iteration
                                #   3. Breaking out of the inner "for" loop 
                                $foundMatch = $true
                                $null = $object2List.RemoveAt($i)
                                break
                            }
                        }
                        if (!$foundMatch) {
                            # no item in Object2 matches the current item in Object1, return false
                            return $false
                        }
                    }
                    # every item in Object1 has a match in Object2, return true
                    return $object2List.Count -eq 0
                }
                else {
                    # iterate and recurse
                    for ($i = 0; $i -lt $Object1.Count; $i++) {
                        $item1 = $Object1[$i]
                        $item2 = $Object2[$i]
                        if ($item1 -eq $item2 -or (Confirm-ObjectValueEqualityDeep $item1 $item2 -CaseInsensitiveKeys:$CaseInsensitiveKeys)) {
                            # if either the array item values are equal or a deep inspection shows equal, continue to the next item
                        }
                        else {
                            # if the array item values are not equal and a deep inspection does not show equal, return false
                            return $false
                        }
                    }
                    # every item in the array has the same value, return true
                    return $true
                }
            }
        }
        elseif ($typeName1 -eq "DateTime" -or $typeName2 -eq "DateTime") {
            # $Object1 or $Object2 is a DateTime
            # Note: this must be done prior to the next test, since [DateTime] is a [System.ValueType]
            $dateString1 = $Object1
            $dateString2 = $Object2
            if ($typeName1 -eq "DateTime") {
                $dateString1 = $Object1.ToString("yyyy-MM-dd")
            }
            if ($typeName2 -eq "DateTime") {
                $dateString2 = $Object2.ToString("yyyy-MM-dd")
            }
            return $dateString1 -eq $dateString2
        }
        elseif ($typeName1 -eq "String" -or $typeName2 -eq "String" -or $Object1 -is [System.ValueType] -or $Object2 -is [System.ValueType]) {
            # Will have caused $true by the first "if" statement if they match
            # Note: this must be done prior to the next test, since [string and [System.ValueType] are both [PSCustomObject] (PSCustomObject is PowerShells version of [object])
            return $false
        }
        elseif (($Object1 -is [System.Collections.IDictionary] -or $Object1 -is [PSCustomObject]) `
                -and ($Object2 -is [System.Collections.IDictionary] -or $Object2 -is [PSCustomObject])) {

            # normalize Object1 and Object2 to hashtable
            $normalizedObject1 = $Object1
            $normalizedObject2 = $Object2
            if ($Object1 -isnot [System.Collections.IDictionary]) {
                $normalizedObject1 = $Object1 | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json -AsHashtable
            }
            if ($Object2 -isnot [System.Collections.IDictionary]) {
                $normalizedObject2 = $Object2 | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json -AsHashtable
            }

            $allKeys = $normalizedObject1.Keys + $normalizedObject2.Keys
            $uniqueKeys = $allKeys | Sort-Object -Unique
            foreach ($key in $uniqueKeys) {
                #recurse
                $item1 = $normalizedObject1.$key
                $item2 = $normalizedObject2.$key
                if ($CaseInsensitiveKeys) {
                    if ($null -eq $item1) {
                        # case of key does not match, find key for normalizedObject1 without considering case
                        $key1 = $normalizedObject1.Keys | Where-Object { $_.ToLower() -eq $key.ToLower() }
                        Write-Debug "key '$key' exists with a different case '$key1' in Object1 '$($normalizedObject1 | ConvertTo-Json -Depth 100 -Compress)'"
                        if ($null -ne $key1) {
                            $item1 = $normalizedObject1.$key1
                        }
                        # else keep $item1 as $null; the recursive call will handle this case
                    }
                    if ($null -eq $item2) {
                        # case of key does not match, find key for normalizedObject2 without considering case
                        $key2 = $normalizedObject2.Keys | Where-Object { $_.ToLower() -eq $key.ToLower() }
                        Write-Debug "key '$key' exists with a different case '$key2' in Object2 '$($normalizedObject2 | ConvertTo-Json -Depth 100 -Compress)'"
                        if ($null -ne $key2) {
                            $item2 = $normalizedObject2.$key2
                        }
                        # else keep $item2 as $null; the recursive call will handle this case
                    }
                }
                if ($item1 -eq $item2 -or (Confirm-ObjectValueEqualityDeep $item1 $item2 -CaseInsensitiveKeys:$CaseInsensitiveKeys -HandleRandomOrderArray:$HandleRandomOrderArray)) {
                    # if the values are equal, or a deep inspection shows equal then continue to the next key
                }
                else {
                    # if the values are not equal, and a deep inspection does not show equal, return false
                    return $false
                }
            }
            # every entry in the collection has the same value, return true
            return $true
        }
        else {
            # equality of other types handled in the then clause of the outer else clause
            return $false
        }
    }
}
