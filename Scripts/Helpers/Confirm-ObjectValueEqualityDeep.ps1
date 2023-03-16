#Requires -PSEdition Core

function Confirm-ObjectValueEqualityDeep {
    [CmdletBinding()]
    param(
        $existingObj,
        $definedObj
    )

    if ($definedObj -eq $existingObj) {
        # Covers $null, value types, strings and objects referring to the same object
        return $true
    }
    elseif ($definedObj -is [datetime] -or $existingObj -is [datetime]) {
        $definedDateString = $definedObj
        if ($definedObj -is [datetime]) {
            $definedDateString = $definedObj.ToString("yyyy-MM-dd")
        }
        $existingDateString = $existingObj
        if ($existingObj -is [datetime]) {
            $existingDateString = $existingObj.ToString("yyyy-MM-dd")
        }
        return $definedDateString -eq $existingDateString
    }
    else {

        # Normalize if PSCustomObject or Hashtable
        $isHashtable = $false
        $definedHashtable = @{}
        if ($null -ne $definedObj) {
            if ($definedObj -is [System.Collections.IDictionary]) {
                $definedHashtable = $definedObj.Clone()
                Remove-EmptyFields -definition $definedHashtable
                $isHashtable = $true
            }
            elseif ($definedObj -is [PSCustomObject] -and $definedObj -isnot [System.Collections.IList]) {
                $definedHashtable = ConvertTo-HashTable $definedObj
                Remove-EmptyFields -definition $definedHashtable
                $isHashtable = $true
            }
        }
        $existingHashtable = @{}
        if ($null -ne $existingObj) {
            if ($existingObj -is [System.Collections.IDictionary]) {
                $existingHashtable = $existingObj.Clone()
                Remove-EmptyFields -definition $existingHashtable
                $isHashtable = $true
            }
            elseif ($existingObj -is [PSCustomObject] -and $existingObj -isnot [System.Collections.IList]) {
                $existingHashtable = ConvertTo-HashTable $existingObj
                Remove-EmptyFields -definition $existingHashtable
                $isHashtable = $true
            }
        }
        if ($isHashtable) {
            if ($definedHashtable.Count -ne $existingHashtable.Count) {
                return $false
            }
            foreach ($key in $existingHashtable.Keys) {
                if ($definedHashtable.ContainsKey($key)) {
                    if (!(Confirm-ObjectValueEqualityDeep -existingObj $existingHt.$key -definedObj $definedHt.$key)) {
                        return $false
                    }
                }
                else {
                    return $false
                }
            }
            return $true
        }
        else {
            # normalize arrays if one or both operands are an array
            $isList = $false
            [array] $definedList = $()
            if ($null -ne $definedObj) {
                if ($definedObj -is [System.Collections.IList]) {
                    $definedList = $definedObj
                    $isList = $true
                }
                else {
                    $definedList += $definedObj
                }
            }
            [array] $existingList = $()
            if ($null -ne $existingObj) {
                if ($existingObj -is [System.Collections.IList]) {
                    $existingList = $existingObj
                    $isList = $true
                }
                else {
                    $existingList += $existingObj
                }
            }
            if ($isList) {
                if ($definedList.Count -ne $existingList.Count) {
                    # arrays of differing lengths are by definition not equal
                    return $false
                }
                elseif ($definedList.Count -eq 0 -and $existingList.Count -eq 0) {
                    # two zero length arrays are equal
                    return $true
                }
                else {
                    $existingArrayList = [System.Collections.ArrayList]::new($existingList)
                    foreach ($definedItem in $definedList) {
                        $foundMatch = $false
                        $existingCount = $existingArrayList.Count
                        for ($i = 0; $i -lt $existingCount; ++$i) {
                            $existingItem = $existingArrayList[$i]
                            if (Confirm-ObjectValueEqualityDeep -existingObj $existingItem -definedObj $definedItem) {
                                $existingArrayList.RemoveAt($i)
                                $foundMatch = $true
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
            else {
                # Value type, equality already tested at beginning
                return $false
            }
        }
    }
}
