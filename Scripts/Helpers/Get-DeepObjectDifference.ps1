function Get-DeepObjectDifference {
    <#
    .SYNOPSIS
    Compares two objects and returns only the differences (changed, added, or removed keys).
    
    .DESCRIPTION
    Recursively compares two objects (hashtables, arrays, or simple values) and returns
    a hashtable containing the differences. Only changed values are returned, not the entire object.
    
    .PARAMETER OldObject
    The original object (from deployed/existing state)
    
    .PARAMETER NewObject
    The new object (from desired state)
    
    .PARAMETER Path
    Internal parameter used for tracking the path during recursion
    
    .OUTPUTS
    Hashtable with structure: @{ path = @{ old = value; new = value; change = "modified|added|removed" } }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        $OldObject,
        
        [Parameter(Position = 1)]
        $NewObject,
        
        [Parameter(Position = 2)]
        [string] $Path = ""
    )
    
    $differences = @{}
    
    # Handle null cases
    if ($null -eq $OldObject -and $null -eq $NewObject) {
        return $differences
    }
    
    if ($null -eq $OldObject) {
        # Everything in NewObject is added
        if ($NewObject -is [hashtable] -or $NewObject -is [System.Collections.IDictionary]) {
            foreach ($key in $NewObject.Keys) {
                $newPath = if ($Path) { "$Path.$key" } else { $key }
                $differences[$newPath] = @{
                    old = $null
                    new = $NewObject[$key]
                    change = "added"
                }
            }
        }
        else {
            $differences[$Path] = @{
                old = $null
                new = $NewObject
                change = "added"
            }
        }
        return $differences
    }
    
    if ($null -eq $NewObject) {
        # Everything in OldObject is removed
        if ($OldObject -is [hashtable] -or $OldObject -is [System.Collections.IDictionary]) {
            foreach ($key in $OldObject.Keys) {
                $newPath = if ($Path) { "$Path.$key" } else { $key }
                $differences[$newPath] = @{
                    old = $OldObject[$key]
                    new = $null
                    change = "removed"
                }
            }
        }
        else {
            $differences[$Path] = @{
                old = $OldObject
                new = $null
                change = "removed"
            }
        }
        return $differences
    }
    
    # Both objects exist - compare them
    if (($OldObject -is [hashtable] -or $OldObject -is [System.Collections.IDictionary]) -and 
        ($NewObject -is [hashtable] -or $NewObject -is [System.Collections.IDictionary])) {
        
        # Get all unique keys
        $allKeys = @($OldObject.Keys) + @($NewObject.Keys) | Select-Object -Unique
        
        foreach ($key in $allKeys) {
            $newPath = if ($Path) { "$Path.$key" } else { $key }
            
            $oldValue = if ($OldObject.ContainsKey($key)) { $OldObject[$key] } else { $null }
            $newValue = if ($NewObject.ContainsKey($key)) { $NewObject[$key] } else { $null }
            
            if ($null -eq $oldValue -and $null -ne $newValue) {
                # Key added
                $differences[$newPath] = @{
                    old = $null
                    new = $newValue
                    change = "added"
                }
            }
            elseif ($null -ne $oldValue -and $null -eq $newValue) {
                # Key removed
                $differences[$newPath] = @{
                    old = $oldValue
                    new = $null
                    change = "removed"
                }
            }
            elseif ($null -ne $oldValue -and $null -ne $newValue) {
                # Check if values are different
                if (($oldValue -is [hashtable] -or $oldValue -is [System.Collections.IDictionary]) -and
                    ($newValue -is [hashtable] -or $newValue -is [System.Collections.IDictionary])) {
                    # Recurse for nested hashtables
                    $nestedDiffs = Get-DeepObjectDifference -OldObject $oldValue -NewObject $newValue -Path $newPath
                    foreach ($diffKey in $nestedDiffs.Keys) {
                        $differences[$diffKey] = $nestedDiffs[$diffKey]
                    }
                }
                elseif (($oldValue -is [array]) -and ($newValue -is [array])) {
                    # For arrays, do a simple comparison
                    $arraysMatch = $true
                    if ($oldValue.Count -ne $newValue.Count) {
                        $arraysMatch = $false
                    }
                    else {
                        for ($i = 0; $i -lt $oldValue.Count; $i++) {
                            if ($oldValue[$i] -ne $newValue[$i]) {
                                $arraysMatch = $false
                                break
                            }
                        }
                    }
                    
                    if (-not $arraysMatch) {
                        $differences[$newPath] = @{
                            old = ($oldValue -join ", ")
                            new = ($newValue -join ", ")
                            change = "modified"
                        }
                    }
                }
                else {
                    # Simple value comparison
                    if ($oldValue -ne $newValue) {
                        $differences[$newPath] = @{
                            old = $oldValue
                            new = $newValue
                            change = "modified"
                        }
                    }
                }
            }
        }
    }
    else {
        # Simple comparison for non-hashtable objects
        if ($OldObject -ne $NewObject) {
            $differences[$Path] = @{
                old = $OldObject
                new = $NewObject
                change = "modified"
            }
        }
    }
    
    return $differences
}
