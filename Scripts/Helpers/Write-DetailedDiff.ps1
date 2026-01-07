function Write-DetailedDiff {
    <#
    .SYNOPSIS
        Generates a detailed, Terraform-style diff output showing line-by-line changes between two objects.
    
    .DESCRIPTION
        This function compares two objects (deployed vs. desired state) and outputs a detailed diff
        similar to terraform plan, showing:
        - Lines with '~' prefix (yellow) for changed values: old_value → new_value
        - Lines with '-' prefix (red) for removed values
        - Lines with '+' prefix (green) for new values
        - Lines without prefix for unchanged values (when ShowUnchanged is true)
    
    .PARAMETER DeployedObject
        The current/deployed object state
    
    .PARAMETER DesiredObject
        The desired/new object state
    
    .PARAMETER PropertyName
        The name of the property being compared (for display purposes)
    
    .PARAMETER Indent
        The indentation level for the output (default: 6)
    
    .PARAMETER ShowUnchanged
        If specified, shows unchanged properties as well
    
    .EXAMPLE
        Write-DetailedDiff -DeployedObject $deployed -DesiredObject $desired -PropertyName "parameters"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $DeployedObject,
        
        [Parameter(Mandatory = $false)]
        $DesiredObject,
        
        [Parameter(Mandatory = $true)]
        [string] $PropertyName,
        
        [Parameter(Mandatory = $false)]
        [int] $Indent = 6,
        
        [Parameter(Mandatory = $false)]
        [switch] $ShowUnchanged
    )

    $indentString = " " * $Indent
    
    Write-ModernStatus -Message "Property: $PropertyName" -Status "info" -Indent $Indent
    
    # Handle null cases
    if ($null -eq $DeployedObject -and $null -eq $DesiredObject) {
        Write-ColoredOutput -Message "$($indentString)  (both values are null)" -ForegroundColor DarkGray
        return
    }
    
    if ($null -eq $DeployedObject) {
        # All new
        Write-ColoredOutput -Message "$($indentString)  ┌─ New Value:" -ForegroundColor DarkGray
        $desiredJson = if ($DesiredObject -is [string]) { $DesiredObject } else { $DesiredObject | ConvertTo-Json -Depth 100 -Compress:$false }
        $desiredLines = $desiredJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        foreach ($line in $desiredLines) {
            Write-ColoredOutput -Message "$($indentString)  + $line" -ForegroundColor Green
        }
        Write-ColoredOutput -Message "$($indentString)  └─────────────" -ForegroundColor DarkGray
        return
    }
    
    if ($null -eq $DesiredObject) {
        # All removed
        Write-ColoredOutput -Message "$($indentString)  ┌─ Removed Value:" -ForegroundColor DarkGray
        $deployedJson = if ($DeployedObject -is [string]) { $DeployedObject } else { $DeployedObject | ConvertTo-Json -Depth 100 -Compress:$false }
        $deployedLines = $deployedJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        foreach ($line in $deployedLines) {
            Write-ColoredOutput -Message "$($indentString)  - $line" -ForegroundColor Red
        }
        Write-ColoredOutput -Message "$($indentString)  └─────────────" -ForegroundColor DarkGray
        return
    }
    
    # Try to do smart object comparison
    try {
        # Convert to hashtables for comparison
        $deployedHash = $null
        $desiredHash = $null
        
        if ($DeployedObject -is [hashtable]) {
            $deployedHash = $DeployedObject
        }
        elseif ($DeployedObject -is [string]) {
            $deployedHash = $DeployedObject | ConvertFrom-Json -AsHashtable -Depth 100
        }
        else {
            $deployedHash = $DeployedObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
        }
        
        if ($DesiredObject -is [hashtable]) {
            $desiredHash = $DesiredObject
        }
        elseif ($DesiredObject -is [string]) {
            $desiredHash = $DesiredObject | ConvertFrom-Json -AsHashtable -Depth 100
        }
        else {
            $desiredHash = $DesiredObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
        }
        
        # Do property-level comparison
        Write-ColoredOutput -Message "$($indentString)  ┌─ Changes:" -ForegroundColor DarkGray
        
        $allKeys = @($deployedHash.Keys) + @($desiredHash.Keys) | Select-Object -Unique | Sort-Object
        $changesDetected = $false
        
        foreach ($key in $allKeys) {
            $deployedValue = $deployedHash[$key]
            $desiredValue = $desiredHash[$key]
            
            # Convert values to comparable strings
            $deployedStr = if ($null -eq $deployedValue) { "null" } elseif ($deployedValue -is [string]) { "`"$deployedValue`"" } else { $deployedValue | ConvertTo-Json -Compress -Depth 100 }
            $desiredStr = if ($null -eq $desiredValue) { "null" } elseif ($desiredValue -is [string]) { "`"$desiredValue`"" } else { $desiredValue | ConvertTo-Json -Compress -Depth 100 }
            
            if ($deployedHash.ContainsKey($key) -and -not $desiredHash.ContainsKey($key)) {
                # Removed property
                Write-ColoredOutput -Message "$($indentString)  - `"$key`": $deployedStr" -ForegroundColor Red
                $changesDetected = $true
            }
            elseif (-not $deployedHash.ContainsKey($key) -and $desiredHash.ContainsKey($key)) {
                # Added property
                Write-ColoredOutput -Message "$($indentString)  + `"$key`": $desiredStr" -ForegroundColor Green
                $changesDetected = $true
            }
            elseif ($deployedStr -ne $desiredStr) {
                # Changed property - show as update with arrow
                Write-ColoredOutput -Message "$($indentString)  ~ `"$key`": $deployedStr → $desiredStr" -ForegroundColor Yellow
                $changesDetected = $true
            }
            elseif ($ShowUnchanged) {
                # Unchanged property
                Write-ColoredOutput -Message "$($indentString)    `"$key`": $deployedStr" -ForegroundColor DarkGray
            }
        }
        
        if (-not $changesDetected) {
            Write-ColoredOutput -Message "$($indentString)  (no changes detected)" -ForegroundColor DarkGray
        }
        
        Write-ColoredOutput -Message "$($indentString)  └─────────────" -ForegroundColor DarkGray
    }
    catch {
        # Fallback to line-by-line comparison if object comparison fails
        Write-ColoredOutput -Message "$($indentString)  ┌─ Changes (text diff):" -ForegroundColor DarkGray
        
        $deployedJson = if ($DeployedObject -is [string]) { $DeployedObject } else { $DeployedObject | ConvertTo-Json -Depth 100 -Compress:$false }
        $desiredJson = if ($DesiredObject -is [string]) { $DesiredObject } else { $DesiredObject | ConvertTo-Json -Depth 100 -Compress:$false }
        
        $deployedLines = $deployedJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        $desiredLines = $desiredJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        
        # Simple line matching
        $maxLines = [Math]::Max($deployedLines.Count, $desiredLines.Count)
        
        for ($i = 0; $i -lt $maxLines; $i++) {
            $deployedLine = if ($i -lt $deployedLines.Count) { $deployedLines[$i] } else { $null }
            $desiredLine = if ($i -lt $desiredLines.Count) { $desiredLines[$i] } else { $null }
            
            if ($null -eq $deployedLine) {
                Write-ColoredOutput -Message "$($indentString)  + $desiredLine" -ForegroundColor Green
            }
            elseif ($null -eq $desiredLine) {
                Write-ColoredOutput -Message "$($indentString)  - $deployedLine" -ForegroundColor Red
            }
            elseif ($deployedLine -ne $desiredLine) {
                Write-ColoredOutput -Message "$($indentString)  - $deployedLine" -ForegroundColor Red
                Write-ColoredOutput -Message "$($indentString)  + $desiredLine" -ForegroundColor Green
            }
            elseif ($ShowUnchanged) {
                Write-ColoredOutput -Message "$($indentString)    $deployedLine" -ForegroundColor DarkGray
            }
        }
        
        Write-ColoredOutput -Message "$($indentString)  └─────────────" -ForegroundColor DarkGray
    }
}

function Write-SimplePropertyDiff {
    <#
    .SYNOPSIS
        Shows a simple before/after comparison for a single property value.
    
    .DESCRIPTION
        Displays the old and new values for a changed property in a concise format.
    
    .PARAMETER PropertyName
        The name of the property
    
    .PARAMETER OldValue
        The current/deployed value
    
    .PARAMETER NewValue
        The desired/new value
    
    .PARAMETER Indent
        The indentation level for the output (default: 6)
    
    .EXAMPLE
        Write-SimplePropertyDiff -PropertyName "enforcementMode" -OldValue "Default" -NewValue "DoNotEnforce"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $PropertyName,
        
        [Parameter(Mandatory = $false)]
        $OldValue,
        
        [Parameter(Mandatory = $false)]
        $NewValue,
        
        [Parameter(Mandatory = $false)]
        [int] $Indent = 6
    )
    
    $indentString = " " * $Indent
    
    # Convert values to strings for display
    $oldValueStr = if ($null -eq $OldValue) { "null" } elseif ($OldValue -is [string]) { "`"$OldValue`"" } else { $OldValue | ConvertTo-Json -Compress }
    $newValueStr = if ($null -eq $NewValue) { "null" } elseif ($NewValue -is [string]) { "`"$NewValue`"" } else { $NewValue | ConvertTo-Json -Compress }
    
    Write-ModernStatus -Message "Property: $PropertyName" -Status "info" -Indent $Indent
    Write-ColoredOutput -Message "$($indentString)  ~ $oldValueStr → $newValueStr" -ForegroundColor Yellow
}
