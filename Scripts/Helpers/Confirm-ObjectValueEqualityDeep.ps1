#Requires -PSEdition Core

function Confirm-ObjectValueEqualityDeep {
    [CmdletBinding()]
    param(
        $existingObj,
        $definedObj
    )

    if (($definedObj -is [hashtable]) -or ($existingObj -is [hashtable]) `
            -or (($definedObj -is [PSCustomObject]) -and ($existingObj -is [PSCustomObject]))) {
        [hashtable] $definedHt = $null
        [hashtable] $existingHt = $null
        if ($definedObj -is [hashtable]) {
            if ($definedObj){$definedHt = $definedObj.clone()}else{$definedHt=@{}}
        }
        else {
            $definedHt = $definedObj | ConvertTo-HashTable
        }
        if ($existingObj -is [hashtable]) {
            if ($existingObj){$existingHt = $existingObj.clone()}else{$existingHt=@{}}
        }
        else {
            $existingHt = $existingObj | ConvertTo-HashTable
        }
        foreach ($key in $existingHt.Keys) {
            if ($definedHt.ContainsKey($key)) {
                if (!(Confirm-ObjectValueEqualityDeep -existingObj $existingHt.$key -definedObj $definedHt.$key)) {
                    return $false
                }
                $null = $definedHt.Remove($key)
            }
            elseif ($null -eq $existingHt.$key) {
                # not existing and null is the same
            }
            else {
                # existing ht has more elements
                return $false
            }
        }
        # Does defined contain additional items
        return $definedHt.Count -lt 1
    }
    elseif ($definedObj -is [array] -or $existingObj -is [array]) {
        [array] $definedArray = $() + $definedObj
        [array] $existingArray = $() + $existingObj
        if (($null -eq $definedObj -and $null -ne $existingObj -and $existingArray.Length -eq 0) -or `
            ($null -eq $existingObj -and $null -ne $definedObj -and $definedArray.Length -eq 0)) {
            # null and zero length is the same
            return $true
        }
        else {
            if ($definedArray.Length -ne $existingArray.Length) {
                return $false
            }
            else {
                $notMatches = $definedArray.Length
                if ($existingArray){$nextExistingArray = $existingArray.clone()}else{$nextExistingArray=@{}}
                foreach ($definedItem in $definedArray) {
                    $found = $false
                    if ($nextExistingArray){$currentArray = $nextExistingArray.clone()}else{$currentArray=@{}}
                    $nextExistingArray = @()
                    foreach ($existingItem in $currentArray) {
                        if ($found) {
                            $nextExistingArray += $existingItem
                        }
                        elseif (Confirm-ObjectValueEqualityDeep -existingObj $existingItem -definedObj $definedItem) {
                            $null = $notMatches--
                            $found = $true
                        }
                        else {
                            $nextExistingArray += $existingItem
                        }
                    }
                    if (!$found) {
                        return $false
                    }
                }
                return $notMatches -lt 1
            }
        }
    }
    else {
        if ($definedObj -is [datetime] -xor $existingObj -is [datetime]) {
            if ($definedObj -is [datetime]) {
                $date = $definedObj.ToString("yyyy-MM-dd")
                return $date -eq $existingObj
            }
            else {
                $date = $existingObj.ToString("yyyy-MM-dd")
                return $date -eq $definedObj
            }
        }
        else {
            return $definedObj -eq $existingObj
        }
    }
}
