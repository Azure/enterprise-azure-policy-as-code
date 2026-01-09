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
        $desiredJson = Convert-ObjectToComparableJson -Object $DesiredObject
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
        $deployedJson = Convert-ObjectToComparableJson -Object $DeployedObject
        $deployedLines = $deployedJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        foreach ($line in $deployedLines) {
            Write-ColoredOutput -Message "$($indentString)  - $line" -ForegroundColor Red
        }
        Write-ColoredOutput -Message "$($indentString)  └─────────────" -ForegroundColor DarkGray
        return
    }
    
    # Check if both objects are arrays - handle them specially
    $isDeployedArray = $DeployedObject -is [array] -or $DeployedObject -is [System.Collections.ArrayList]
    $isDesiredArray = $DesiredObject -is [array] -or $DesiredObject -is [System.Collections.ArrayList]
    
    if ($isDeployedArray -or $isDesiredArray) {
        # Try smart array comparison for arrays of objects (like overrides)
        try {
            # Check if this is an array of objects (hashtables) - use smart comparison
            $isObjectArray = $false
            if ($isDeployedArray -and $DeployedObject.Count -gt 0) {
                $isObjectArray = ($DeployedObject[0] -is [hashtable] -or $DeployedObject[0] -is [System.Management.Automation.PSCustomObject])
            }
            elseif ($isDesiredArray -and $DesiredObject.Count -gt 0) {
                $isObjectArray = ($DesiredObject[0] -is [hashtable] -or $DesiredObject[0] -is [System.Management.Automation.PSCustomObject])
            }
            
            if ($isObjectArray -and $PropertyName -match "Override|Selector|Message|Policy Definitions") {
                # Smart comparison for arrays of objects
                Write-ColoredOutput -Message "$($indentString)  ┌─ Changes:" -ForegroundColor DarkGray
                
                # Convert to comparable format
                $deployedItems = @()
                $desiredItems = @()
                
                if ($null -ne $DeployedObject) {
                    foreach ($item in $DeployedObject) {
                        # For policy definitions, normalize by removing API-added fields before comparison
                        if ($PropertyName -match "Policy Definitions") {
                            $normalizedItem = @{
                                policyDefinitionId = $item.policyDefinitionId
                                policyDefinitionReferenceId = $item.policyDefinitionReferenceId
                                parameters = $item.parameters
                            }
                            $deployedItems += @{
                                json = (Convert-ObjectToComparableJson -Object $normalizedItem -Compress)
                                obj = $item
                                normalizedObj = $normalizedItem
                            }
                        }
                        else {
                            $deployedItems += @{
                                json = (Convert-ObjectToComparableJson -Object $item -Compress)
                                obj = $item
                            }
                        }
                    }
                }
                
                if ($null -ne $DesiredObject) {
                    foreach ($item in $DesiredObject) {
                        # For policy definitions, normalize by removing API-added fields before comparison
                        if ($PropertyName -match "Policy Definitions") {
                            $normalizedItem = @{
                                policyDefinitionId = $item.policyDefinitionId
                                policyDefinitionReferenceId = $item.policyDefinitionReferenceId
                                parameters = $item.parameters
                            }
                            $desiredItems += @{
                                json = (Convert-ObjectToComparableJson -Object $item -Compress)
                                obj = $item
                                normalizedObj = $normalizedItem
                            }
                        }
                        else {
                            $desiredItems += @{
                                json = (Convert-ObjectToComparableJson -Object $item -Compress)
                                obj = $item
                            }
                        }
                    }
                }
                
                # Find removed, added, modified, and unchanged items
                $removedItems = @()
                $addedItems = @()
                $modifiedItems = @()
                $unchangedCount = 0
                $processedDesired = @{}
                
                # Check what was removed or modified
                foreach ($deployed in $deployedItems) {
                    $exactMatch = $false
                    $partialMatch = $null
                    
                    # First check for exact match
                    for ($i = 0; $i -lt $desiredItems.Count; $i++) {
                        if ($deployed.json -eq $desiredItems[$i].json) {
                            $exactMatch = $true
                            $processedDesired[$i] = $true
                            $unchangedCount++
                            break
                        }
                    }
                    
                    # If no exact match, check for partial match (same kind/value for overrides, same referenceId for policy definitions)
                    if (-not $exactMatch) {
                        for ($i = 0; $i -lt $desiredItems.Count; $i++) {
                            if ($processedDesired.ContainsKey($i)) { continue }
                            
                            $deployedObj = $deployed.obj
                            $desiredObj = $desiredItems[$i].obj
                            
                            # Check if kind and value match (indicating it's the same override type)
                            if ($PropertyName -match "Override" -and $deployedObj.kind -eq $desiredObj.kind -and $deployedObj.value -eq $desiredObj.value) {
                                $partialMatch = @{
                                    deployed = $deployed
                                    desired = $desiredItems[$i]
                                    index = $i
                                }
                                $processedDesired[$i] = $true
                                break
                            }
                            # Check if policyDefinitionReferenceId matches (indicating it's the same policy definition)
                            elseif ($PropertyName -match "Policy Definitions" -and $deployedObj.policyDefinitionReferenceId -eq $desiredObj.policyDefinitionReferenceId) {
                                $partialMatch = @{
                                    deployed = $deployed
                                    desired = $desiredItems[$i]
                                    index = $i
                                }
                                $processedDesired[$i] = $true
                                break
                            }
                        }
                    }
                    
                    if ($exactMatch) {
                        # Already counted as unchanged
                    }
                    elseif ($null -ne $partialMatch) {
                        # This is a modification
                        $modifiedItems += $partialMatch
                    }
                    else {
                        # This was removed
                        $removedItems += $deployed
                    }
                }
                
                # Check what was truly added (not part of a modification)
                for ($i = 0; $i -lt $desiredItems.Count; $i++) {
                    if (-not $processedDesired.ContainsKey($i)) {
                        $addedItems += $desiredItems[$i]
                    }
                }
                
                $changesDetected = ($removedItems.Count -gt 0) -or ($addedItems.Count -gt 0) -or ($modifiedItems.Count -gt 0)
                
                # Display summary
                if ($unchangedCount -gt 0) {
                    Write-ColoredOutput -Message "$($indentString)  ≈ $unchangedCount item(s) unchanged" -ForegroundColor DarkGray
                }
                
                # Display modified items with context
                if ($modifiedItems.Count -gt 0) {
                    # Filter to only show items with actual changes
                    $actuallyModifiedItems = @()
                    foreach ($mod in $modifiedItems) {
                        $deployedObj = $mod.deployed.obj
                        $desiredObj = $mod.desired.obj
                        
                        # For Policy Definitions, compare the normalized objects
                        if ($PropertyName -match "Policy Definitions") {
                            $deployedNorm = $mod.deployed.normalizedObj
                            $desiredNorm = $mod.desired.normalizedObj
                            
                            $deployedJson = Convert-ObjectToComparableJson -Object $deployedNorm -Compress
                            $desiredJson = Convert-ObjectToComparableJson -Object $desiredNorm -Compress
                            
                            # Only include if normalized versions differ
                            if ($deployedJson -ne $desiredJson) {
                                $actuallyModifiedItems += @{
                                    mod = $mod
                                    type = "PolicyDefinition"
                                }
                            }
                            else {
                                # No actual changes, count as unchanged
                                $unchangedCount++
                            }
                        }
                        else {
                            # For Overrides, check selectors
                            # Extract the 'in' arrays from selectors
                            $deployedArrays = Get-SelectorArrays -SelectorObject $deployedObj
                            $desiredArrays = Get-SelectorArrays -SelectorObject $desiredObj
                            
                            $deployedIn = $deployedArrays.In
                            $desiredIn = $desiredArrays.In
                            
                            # Find added and removed selector values
                            $removedSelectors = @()
                            $addedSelectors = @()
                            
                            foreach ($item in $deployedIn) {
                                if ($item -notin $desiredIn) {
                                    $removedSelectors += $item
                                }
                            }
                            
                            foreach ($item in $desiredIn) {
                                if ($item -notin $deployedIn) {
                                    $addedSelectors += $item
                                }
                            }
                            
                            # Only include if there are actual changes
                            if ($removedSelectors.Count -gt 0 -or $addedSelectors.Count -gt 0) {
                                $actuallyModifiedItems += @{
                                    mod = $mod
                                    removedSelectors = $removedSelectors
                                    addedSelectors = $addedSelectors
                                    type = "Override"
                                }
                            }
                            else {
                                # No actual changes, count as unchanged
                                $unchangedCount++
                            }
                        }
                    }
                    
                    if ($actuallyModifiedItems.Count -gt 0) {
                        Write-ColoredOutput -Message "$($indentString)  ~ Modified $($actuallyModifiedItems.Count) item(s):" -ForegroundColor Yellow
                        foreach ($modItem in $actuallyModifiedItems) {
                            $mod = $modItem.mod
                            
                            if ($modItem.type -eq "PolicyDefinition") {
                                # Display policy definition changes using normalized comparison
                                $deployedNorm = $mod.deployed.normalizedObj
                                $desiredNorm = $mod.desired.normalizedObj
                                
                                # Show a compact diff for policy definitions
                                Write-ColoredOutput -Message "$($indentString)    Policy: $($desiredNorm.policyDefinitionReferenceId)" -ForegroundColor Cyan
                                
                                # Compare each property
                                if ($deployedNorm.policyDefinitionId -ne $desiredNorm.policyDefinitionId) {
                                    Write-ColoredOutput -Message "$($indentString)      ~ policyDefinitionId: $($deployedNorm.policyDefinitionId) → $($desiredNorm.policyDefinitionId)" -ForegroundColor Yellow
                                }
                                
                                $deployedParamsJson = Convert-ObjectToComparableJson -Object $deployedNorm.parameters -Compress
                                $desiredParamsJson = Convert-ObjectToComparableJson -Object $desiredNorm.parameters -Compress
                                if ($deployedParamsJson -ne $desiredParamsJson) {
                                    Write-ColoredOutput -Message "$($indentString)      ~ parameters changed" -ForegroundColor Yellow
                                    Write-ColoredOutput -Message "$($indentString)        - $deployedParamsJson" -ForegroundColor Red
                                    Write-ColoredOutput -Message "$($indentString)        + $desiredParamsJson" -ForegroundColor Green
                                }
                            }
                            else {
                                # Display override changes with selector diff
                                $removedSelectors = $modItem.removedSelectors
                                $addedSelectors = $modItem.addedSelectors
                                
                                $deployedObj = $mod.deployed.obj
                                $desiredObj = $mod.desired.obj
                                
                                # Extract the 'in' arrays from selectors for unchanged tracking
                                $deployedArrays = Get-SelectorArrays -SelectorObject $deployedObj
                                $desiredArrays = Get-SelectorArrays -SelectorObject $desiredObj
                                
                                $deployedIn = $deployedArrays.In
                                $desiredIn = $desiredArrays.In
                                $unchangedSelectors = @()
                                
                                foreach ($item in $deployedIn) {
                                    if ($item -in $desiredIn) {
                                        $unchangedSelectors += $item
                                    }
                                }
                            
                            # Build a merged structure showing both removed and added items
                            # We'll parse the JSON and reconstruct with changes
                            $deployedJson = Convert-ObjectToComparableJson -Object $deployedObj
                            $desiredJson = Convert-ObjectToComparableJson -Object $desiredObj
                            
                            $deployedLines = $deployedJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
                            $desiredLines = $desiredJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
                            
                            # Show structure with inline changes
                            $inInArray = $false
                            $shownLines = @{}
                            
                            foreach ($line in $desiredLines) {
                                $trimmedLine = $line.Trim()
                                
                                # Check if we're entering/in the "in" array
                                if ($trimmedLine -match '^"in":\s*\[') {
                                    $inInArray = $true
                                    Write-ColoredOutput -Message "$($indentString)      $line" -ForegroundColor DarkGray
                                    
                                    # Now show removed selectors first
                                    # Match the indentation of array items (extract from the line itself)
                                    $baseIndent = if ($line -match '^(\s+)"in"') { $matches[1] + '  ' } else { '        ' }
                                    foreach ($removed in $removedSelectors) {
                                        Write-ColoredOutput -Message "$($indentString)    - $baseIndent`"$removed`"," -ForegroundColor Red
                                    }
                                    continue
                                }
                                elseif ($inInArray -and $trimmedLine -eq ']' -or $trimmedLine -eq '],') {
                                    $inInArray = $false
                                }
                                
                                # Check if this line is in the "in" array
                                if ($inInArray) {
                                    # Check if this is a selector value line
                                    $isSelector = $false
                                    foreach ($added in $addedSelectors) {
                                        if ($line -match [regex]::Escape("`"$added`"")) {
                                            Write-ColoredOutput -Message "$($indentString)    + $line" -ForegroundColor Green
                                            $isSelector = $true
                                            break
                                        }
                                    }
                                    
                                    if (-not $isSelector) {
                                        foreach ($unchanged in $unchangedSelectors) {
                                            if ($line -match [regex]::Escape("`"$unchanged`"")) {
                                                Write-ColoredOutput -Message "$($indentString)      $line" -ForegroundColor DarkGray
                                                $isSelector = $true
                                                break
                                            }
                                        }
                                    }
                                    
                                    if (-not $isSelector) {
                                        # Non-selector line within in array
                                        Write-ColoredOutput -Message "$($indentString)      $line" -ForegroundColor DarkGray
                                    }
                                }
                                else {
                                    # Outside the "in" array - show as context
                                    Write-ColoredOutput -Message "$($indentString)      $line" -ForegroundColor DarkGray
                                }
                            }
                            }
                        }
                    }
                }
                
                # Display removed items
                if ($removedItems.Count -gt 0) {
                    Write-ColoredOutput -Message "$($indentString)  - Removed $($removedItems.Count) item(s):" -ForegroundColor Red
                    foreach ($item in $removedItems) {
                        $itemJson = Convert-ObjectToComparableJson -Object $item.obj
                        $itemLines = $itemJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
                        foreach ($line in $itemLines) {
                            Write-ColoredOutput -Message "$($indentString)    - $line" -ForegroundColor Red
                        }
                    }
                }
                
                # Display added items
                if ($addedItems.Count -gt 0) {
                    Write-ColoredOutput -Message "$($indentString)  + Added $($addedItems.Count) item(s):" -ForegroundColor Green
                    foreach ($item in $addedItems) {
                        $itemJson = Convert-ObjectToComparableJson -Object $item.obj
                        $itemLines = $itemJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
                        foreach ($line in $itemLines) {
                            Write-ColoredOutput -Message "$($indentString)    + $line" -ForegroundColor Green
                        }
                    }
                }
                
                if (-not $changesDetected) {
                    Write-ColoredOutput -Message "$($indentString)  (no changes detected)" -ForegroundColor DarkGray
                }
                
                Write-ColoredOutput -Message "$($indentString)  └─────────────" -ForegroundColor DarkGray
                return
            }
        }
        catch {
            # Fall through to simple array comparison
        }
        
        # Fallback: Use JSON-based line-by-line comparison for arrays
        Write-ColoredOutput -Message "$($indentString)  ┌─ Changes:" -ForegroundColor DarkGray
        
        $deployedJson = Convert-ObjectToComparableJson -Object $DeployedObject
        $desiredJson = Convert-ObjectToComparableJson -Object $DesiredObject
        
        $deployedLines = $deployedJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        $desiredLines = $desiredJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        
        # Track if any changes were detected
        $changesDetected = $false
        
        # Simple line matching
        $maxLines = [Math]::Max($deployedLines.Count, $desiredLines.Count)
        
        for ($i = 0; $i -lt $maxLines; $i++) {
            $deployedLine = if ($i -lt $deployedLines.Count) { $deployedLines[$i] } else { $null }
            $desiredLine = if ($i -lt $desiredLines.Count) { $desiredLines[$i] } else { $null }
            
            if ($null -eq $deployedLine) {
                Write-ColoredOutput -Message "$($indentString)  + $desiredLine" -ForegroundColor Green
                $changesDetected = $true
            }
            elseif ($null -eq $desiredLine) {
                Write-ColoredOutput -Message "$($indentString)  - $deployedLine" -ForegroundColor Red
                $changesDetected = $true
            }
            elseif ($deployedLine -ne $desiredLine) {
                Write-ColoredOutput -Message "$($indentString)  - $deployedLine" -ForegroundColor Red
                Write-ColoredOutput -Message "$($indentString)  + $desiredLine" -ForegroundColor Green
                $changesDetected = $true
            }
            elseif ($ShowUnchanged) {
                Write-ColoredOutput -Message "$($indentString)    $deployedLine" -ForegroundColor DarkGray
            }
        }
        
        if (-not $changesDetected) {
            Write-ColoredOutput -Message "$($indentString)  (no changes detected)" -ForegroundColor DarkGray
        }
        
        Write-ColoredOutput -Message "$($indentString)  └─────────────" -ForegroundColor DarkGray
        return
    }
    
    # Try to do smart object comparison for hashtables/objects
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
            $deployedStr = ConvertTo-DisplayString -Value $deployedValue
            $desiredStr = ConvertTo-DisplayString -Value $desiredValue
            
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
        
        $deployedJson = Convert-ObjectToComparableJson -Object $DeployedObject
        $desiredJson = Convert-ObjectToComparableJson -Object $DesiredObject
        
        $deployedLines = $deployedJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        $desiredLines = $desiredJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
        
        # Track if any changes were detected
        $changesDetected = $false
        
        # Simple line matching
        $maxLines = [Math]::Max($deployedLines.Count, $desiredLines.Count)
        
        for ($i = 0; $i -lt $maxLines; $i++) {
            $deployedLine = if ($i -lt $deployedLines.Count) { $deployedLines[$i] } else { $null }
            $desiredLine = if ($i -lt $desiredLines.Count) { $desiredLines[$i] } else { $null }
            
            if ($null -eq $deployedLine) {
                Write-ColoredOutput -Message "$($indentString)  + $desiredLine" -ForegroundColor Green
                $changesDetected = $true
            }
            elseif ($null -eq $desiredLine) {
                Write-ColoredOutput -Message "$($indentString)  - $deployedLine" -ForegroundColor Red
                $changesDetected = $true
            }
            elseif ($deployedLine -ne $desiredLine) {
                Write-ColoredOutput -Message "$($indentString)  - $deployedLine" -ForegroundColor Red
                Write-ColoredOutput -Message "$($indentString)  + $desiredLine" -ForegroundColor Green
                $changesDetected = $true
            }
            elseif ($ShowUnchanged) {
                Write-ColoredOutput -Message "$($indentString)    $deployedLine" -ForegroundColor DarkGray
            }
        }
        
        if (-not $changesDetected) {
            Write-ColoredOutput -Message "$($indentString)  (no changes detected)" -ForegroundColor DarkGray
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
    $oldValueStr = ConvertTo-DisplayString -Value $OldValue
    $newValueStr = ConvertTo-DisplayString -Value $NewValue
    
    Write-ModernStatus -Message "Property: $PropertyName" -Status "info" -Indent $Indent
    Write-ColoredOutput -Message "$($indentString)  ~ $oldValueStr → $newValueStr" -ForegroundColor Yellow
}
