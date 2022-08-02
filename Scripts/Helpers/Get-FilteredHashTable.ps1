#Requires -PSEdition Core

function Get-FilteredHashTable {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [pscustomobject] $splat,

        [Parameter()]
        [string] $splatTransform = $null

    )

    [hashtable] $filteredSplat = @{}
    if ($null -ne $splat) {
        # ignore an empty splat
        if (-not ($splat -is [hashtable])) {
            $ht = $splat | ConvertTo-HashTable
            $splat = $ht
        }

        $transforms = $splat.Keys
        if ($splatTransform) {
            $transforms = $splatTransform.Split()
        }
        foreach ($transform in $transforms) {
            $splits = $transform.Split("/")
            $splatSelector = $splits[0]
            if ($splat.ContainsKey($splatSelector)) {
                $argName = $splatSelector
                $argValue = $splat.$splatSelector
                $splatValue = $argValue

                # Infer format from data type
                $type = "value"
                if ($null -eq $splatValue -or $splatValue -eq "") {
                    $type = "key"
                }
                elseif ($splatValue -is [array]) {
                    $type = "array"
                    foreach ($value in $splatValue) {
                        if (-not($value -is [string] -or $value -is [System.ValueType])) {
                            $type = "json"
                            break
                        }
                    }
                }
                elseif ($splatValue -is [string] -or $splatValue -is [System.ValueType]) {
                    $type = "value"
                }
                else {
                    $type = "json"
                }

                # Check overrides
                if ($splits.Length -in @(2, 3)) {
                    if ($splits[1] -in @("json", "array", "key", "value")) {
                        # Infered type is explicitly overriden
                        $type = $splits[1]
                        if ($splits.Length -eq 3) {
                            $argName = $splits[2]
                        }
                    }
                    elseif ($splits.Length -eq 2) {
                        # Inferred type used and the second part is the newArgName
                        $argName = $splits[1]
                    }
                    else {
                        # Unknown type specified
                        Write-Error "Invalid `splatTransform = '$transform', second part must be one of the following json, array, keyvalues, key, string, value." -ErrorAction Stop
                    }
                }
                switch ($type) {
                    "json" {
                        $argValue = ConvertTo-Json $splatValue -Depth 100
                        $null = $filteredSplat.Add($argName, $argValue)
                    }
                    "key" {
                        # Just the key (no value)
                        $null = $filteredSplat.Add($argName, $true)
                    }
                    "value" {
                        $null = $filteredSplat.Add($argName, $argValue)
                    }
                    "array" {
                        $null = $filteredSplat.Add($argName, $argValue)
                    }
                    Default {
                        Write-Error "Unknown format '$_' for -splatTransform specified '$transform'" -ErrorAction Stop
                        break
                    }
                }
            }
        }
    }

    return $filteredSplat
}