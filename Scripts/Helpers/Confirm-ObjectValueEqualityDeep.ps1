function Confirm-ObjectValueEqualityDeep {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        $Object1,

        [Parameter(Position = 1)]
        $Object2
    )

    if ($null -eq $Object1 -or $null -eq $Object2) {
        if ($Object1 -eq $Object2) {
            # $Object1 and $Object2 are both $null
            return $true
        }
        if ($null -eq $Object1) {
            # $Object1 is $null, swap $Object1 and $Object2 to ensure that Object1 (the old Object2) is not $null and Object2 (the old Object1) is $null (setting it to $null is omitted because it is not used in the subsequent code)
            $Object1 = $Object2
            $Object2 = $null
        }
        if ($Object1 -is [System.Collections.ICollection]) {
            # $Object1 is an ICollection, if it has 0 elements treat it as $null and therefore equal to Object2
            # Arrays, ArrayList, Hashtables and other collections are all ICollection
            return $Object1.Count -eq 0
        }
        elseif ($Object1 -is [string]) {
            # $Object1 is a string, if it is empty or only contains whitespace treat it as $null and therefore equal to Object2
            return [string]::IsNullOrWhiteSpace($Object1)
        }
        else {
            # $Object1 has something else and not null and therefore not equal to Object2
            return $false
        }
    }
    else {
        if ($Object1 -is [System.Collections.IList] -or $Object2 -is [System.Collections.Ilist]) {
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
                $object2List = [System.Collections.ArrayList]::new($Object2)
                foreach ($item1 in $Object1) {
                    # iterate through Object1 and find a match in Object2
                    $foundMatch = $false
                    for ($i = 0; $i -lt $object2List.Count; $i++) {
                        $item2 = $object2List[$i]
                        if (Confirm-ObjectValueEqualityDeep $item1 $item2) {
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
                return $true
            }
        }
        elseif ($Object1 -eq $Object2) {
            # $Object1 and $Object2 are the same object; not correct for a list (IList)
            # therefore check fo a list be first
            # @("S") -eq @("T","S","N") is an empty array => false  if used in an if
            # @("T","S","N") -eq @("S") is @("S")         => true if used in an if
            return $true
        }
        elseif ($Object1 -is [datetime] -or $Object2 -is [datetime]) {
            # $Object1 or $Object2 is a DateTime
            # Note: this must be done prior to the next test, since [DateTime] is a [System.ValueType]
            $dateString1 = $Object1
            $dateString2 = $Object2
            if ($typeName1 -is [datetime]) {
                $dateString1 = $Object1.ToString("yyyy-MM-dd")
            }
            if ($typeName2 -is [datetime]) {
                $dateString2 = $Object2.ToString("yyyy-MM-dd")
            }
            return $dateString1 -eq $dateString2
        }
        elseif ($Object1 -is [string] -or $Object2 -is [string]) {
            # Will have caused $true by the second "if" statement if they match
            # Note: this must be done prior to the next test, since [string and [System.ValueType]
            #       are both [PSCustomObject] (PSCustomObject is PowerShells version of [object])
        }
        elseif (($Object1 -is [System.Collections.IDictionary] -or $Object1 -is [psobject]) `
                -and ($Object2 -is [System.Collections.IDictionary] -or $Object2 -is [psobject])) {

            # normalize Object1 and Object2 keys or property names
            $normalizedKeys1 = @()
            $normalizedKeys2 = @()
            if ($Object1 -is [System.Collections.IDictionary]) {
                $normalizedKeys1 = $Object1.Keys
            }
            else {
                $normalizedKeys1 = $Object1.PSObject.Properties.Name
                if ($normalizedKeys1 -isnot [System.Collections.ICollection]) {
                    $normalizedKeys1 = @($normalizedKeys1)
                }
            }
            if ($Object2 -is [System.Collections.IDictionary]) {
                $normalizedKeys2 = $Object2.Keys
            }
            else {
                $normalizedKeys2 = $Object2.PSObject.Properties.Name
                if ($normalizedKeys2 -isnot [System.Collections.ICollection]) {
                    $normalizedKeys2 = @($normalizedKeys2)
                }
            }

            $allKeys = $normalizedKeys1 + $normalizedKeys2
            $uniqueKeys = $allKeys | Sort-Object -Unique
            if ($null -eq $uniqueKeys) {
                # if there are no keys, return true
                return $true
            }
            if ($uniqueKeys -isnot [System.Collections.ICollection]) {
                $uniqueKeys = @($uniqueKeys)
            }

            # iterate and recurse
            foreach ($key in $uniqueKeys) {
                $item1 = $Object1.$key
                if ($null -eq $item1) {
                    # property missing
                    $key1Array = $normalizedKeys1 -eq $key
                    if ($key1Array.Count -gt 0) {
                        # found a matching key (case insensitive)
                        $key1 = $key1Array[0]
                        $item1 = $Object1.$key1
                    }
                }
                $item2 = $Object2.$key
                if ($null -eq $item2) {
                    # property missing
                    $key2Array = $normalizedKeys2 -eq $key
                    if ($key2Array.Count -gt 0) {
                        # found a matching key (case insensitive)
                        $key2 = $key2Array[0]
                        $item2 = $Object2.$key2
                    }
                }
                $match = Confirm-ObjectValueEqualityDeep $item1 $item2
                if (!$match) {
                    return $false
                }
            }
            # every entry in the collection has the same value, return true
            return $true
        }
        else {
            return $false
        }
    }
}
