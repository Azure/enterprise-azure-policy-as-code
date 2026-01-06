function Write-ModernDiff {
    <#
    .SYNOPSIS
    Renders Terraform-style diff output for resource changes.
    
    .DESCRIPTION
    Displays detailed property-level changes with before/after values using Terraform-style visualization.
    Supports multiple granularity levels: standard, detailed, verbose.
    Supports all operation types: new, update, replace, delete.
    
    .PARAMETER ResourceType
    The type of resource (e.g., "Policy", "PolicySet", "Assignment")
    
    .PARAMETER Resources
    Hashtable of resources with diff arrays attached
    
    .PARAMETER Operation
    The operation being performed: new, update, replace, or delete
    
    .PARAMETER Granularity
    Diff detail level: standard, detailed, or verbose
    
    .PARAMETER Indent
    Number of spaces to indent the output
    
    .EXAMPLE
    Write-ModernDiff -ResourceType "Assignments" -Resources $plan.assignments.update -Operation "update" -Granularity "standard" -Indent 2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResourceType,
        
        [Parameter(Mandatory = $true)]
        [hashtable] $Resources,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("new", "update", "replace", "delete")]
        [string] $Operation = "update",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("standard", "detailed", "verbose")]
        [string] $Granularity = "standard",
        
        [Parameter(Mandatory = $false)]
        [int] $Indent = 2
    )
    
    if ($Resources.Count -eq 0) {
        return
    }
    
    $theme = Get-OutputTheme
    $statusColors = $theme.colors.status
    $prefix = " " * $Indent
    
    foreach ($resourceEntry in $Resources.GetEnumerator()) {
        $resourceId = $resourceEntry.Key
        $resource = $resourceEntry.Value
        
        # Display resource header with appropriate symbol and color
        $displayName = if ($resource.displayName) { $resource.displayName } elseif ($resource.name) { $resource.name } else { $resourceId }
        
        $symbol = switch ($Operation) {
            "new" { "✓" }
            "update" { "~" }
            "replace" { "⭮" }
            "delete" { "X" }
            default { "•" }
        }
        
        $color = switch ($Operation) {
            "new" { $statusColors.success }
            "update" { $statusColors.update }
            "replace" { $statusColors.warning }
            "delete" { $statusColors.error }
            default { $statusColors.info }
        }
        
        $operationText = switch ($Operation) {
            "new" { "New" }
            "update" { "Update" }
            "replace" { "Replace" }
            "delete" { "Delete" }
            default { "Change" }
        }
        
        $headerLine = "$prefix$symbol ${operationText} [$ResourceType]: $displayName"
        Write-Host $headerLine -ForegroundColor $color
        
        if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
            $Global:epacInfoStream += $headerLine
        }
        
        # For replace operations, explain why it's a replace instead of an update
        if ($Operation -eq "replace") {
            $replaceReasons = @()
            
            # Check if replacement reason was stored during planning
            if ($resource.replacementReason -and $resource.replacementReason.Count -gt 0) {
                $replaceReasons = $resource.replacementReason
            }
            else {
                # Fallback: Check for identity-related reasons
                if ($resource.identityStatus -and $resource.identityStatus.replaced) {
                    if ($resource.identityStatus.changedIdentityStrings -and $resource.identityStatus.changedIdentityStrings.Count -gt 0) {
                        $replaceReasons += $resource.identityStatus.changedIdentityStrings
                    }
                    else {
                        $replaceReasons += "identity change"
                    }
                }
                
                # Check for definition ID changes
                if ($resource.policyDefinitionId -ne $resource.oldPolicyDefinitionId -and $resource.oldPolicyDefinitionId) {
                    $replaceReasons += "definitionId"
                }
                
                # Check if definition was replaced
                if ($resource.replacedDefinition) {
                    $replaceReasons += "replacedDefinition"
                }
                
                # If still no reasons found, check diff for immutable property changes
                if ($replaceReasons.Count -eq 0 -and $resource.diff -and $resource.diff.Count -gt 0) {
                    $replaceReasons += "immutable properties changed"
                }
            }
            
            if ($replaceReasons.Count -gt 0) {
                # Format the reasons to be more readable
                $formattedReasons = $replaceReasons | ForEach-Object {
                    switch ($_) {
                        "definitionId" { "policy definition changed" }
                        "replacedDefinition" { "referenced definition replaced" }
                        "displayName" { "display name changed" }
                        "description" { "description changed" }
                        "owner" { "ownership changed" }
                        "metadata" { "metadata changed" }
                        "definitionVersion" { "definition version changed" }
                        "parameters" { "parameters changed" }
                        "enforcementMode" { "enforcement mode changed" }
                        "notScopes" { "exclusion scopes changed" }
                        "nonComplianceMessages" { "non-compliance messages changed" }
                        "overrides" { "overrides changed" }
                        "resourceSelectors" { "resource selectors changed" }
                        "assignmentId" { "policy assignment ID changed" }
                        "replacedAssignment" { "referenced policy assignment was replaced" }
                        default { $_ }
                    }
                }
                
                $reasonLine = "$($prefix)  ! Requires recreation due to: $($formattedReasons -join ', ')"
                Write-Host $reasonLine -ForegroundColor $statusColors.warning
                if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                    $Global:epacInfoStream += $reasonLine
                }
            }
        }
        
        # Display diffs if available (for update, replace operations)
        if ($resource.diff -and $resource.diff.Count -gt 0) {
            foreach ($diffEntry in $resource.diff) {
                $diffLine = Format-DiffEntry -DiffEntry $diffEntry -Granularity $Granularity -Indent ($Indent + 2)
                Write-Host $diffLine.text -ForegroundColor $diffLine.color
                
                if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                    $Global:epacInfoStream += $diffLine.text
                }
            }
        }
        elseif ($resource.identityChanges) {
            # Handle identity changes (legacy format from Build-AssignmentIdentityChanges)
            $identityLine = "$($prefix)  ~ Identity changes detected"
            Write-Host $identityLine -ForegroundColor $statusColors.update
            
            if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                $Global:epacInfoStream += $identityLine
            }
        }
        elseif ($Operation -eq "new" -or $Operation -eq "delete") {
            # For delete operations, show additional details
            if ($Operation -eq "delete") {
                # Show policy definition for assignments
                if ($resource.policyDefinitionId) {
                    $defLine = "$($prefix)  • Policy: $($resource.policyDefinitionId)"
                    Write-Host $defLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $defLine
                    }
                }
                
                # Show scope right after policy
                if ($resource.scope) {
                    $scopeLine = "$($prefix)  • Scope: $($resource.scope)"
                    Write-Host $scopeLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $scopeLine
                    }
                }
                
                # Show description
                if ($resource.description) {
                    $descLine = "$($prefix)  • Description: $($resource.description)"
                    Write-Host $descLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $descLine
                    }
                }
                
                # Show enforcement mode
                if ($resource.enforcementMode) {
                    $modeLine = "$($prefix)  • Enforcement: $($resource.enforcementMode)"
                    Write-Host $modeLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $modeLine
                    }
                }
                
                # Show identity type if present
                if ($resource.identity -and $resource.identity.type -and $resource.identity.type -ne "None") {
                    $identityLine = "$($prefix)  • Identity: $($resource.identity.type)"
                    Write-Host $identityLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $identityLine
                    }
                }
                
                # Show metadata if present (e.g., category, version)
                if ($resource.metadata) {
                    if ($resource.metadata.category) {
                        $categoryLine = "$($prefix)  • Category: $($resource.metadata.category)"
                        Write-Host $categoryLine -ForegroundColor $statusColors.info
                        if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                            $Global:epacInfoStream += $categoryLine
                        }
                    }
                    if ($resource.metadata.version) {
                        $versionLine = "$($prefix)  • Version: $($resource.metadata.version)"
                        Write-Host $versionLine -ForegroundColor $statusColors.info
                        if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                            $Global:epacInfoStream += $versionLine
                        }
                    }
                }
                
                # Show assignment ID and name for exemptions
                if ($resource.policyAssignmentId) {
                    $assignmentLine = "$($prefix)  • Assignment ID: $($resource.policyAssignmentId)"
                    Write-Host $assignmentLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $assignmentLine
                    }
                    
                    # Show assignment display name if available
                    if ($resource.assignmentDisplayName) {
                        $assignmentNameLine = "$($prefix)  • Assignment Name: $($resource.assignmentDisplayName)"
                        Write-Host $assignmentNameLine -ForegroundColor $statusColors.info
                        if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                            $Global:epacInfoStream += $assignmentNameLine
                        }
                    }
                }
                
                # Show policy definition reference IDs for exemptions (specific policies within an initiative)
                if ($resource.policyDefinitionReferenceIds -and $resource.policyDefinitionReferenceIds.Count -gt 0) {
                    $refIdsLine = "$($prefix)  • Policy Definition References: $($resource.policyDefinitionReferenceIds -join ', ')"
                    Write-Host $refIdsLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $refIdsLine
                    }
                }
                
                # Show exemption category
                if ($resource.exemptionCategory) {
                    $categoryLine = "$($prefix)  • Exemption Category: $($resource.exemptionCategory)"
                    Write-Host $categoryLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $categoryLine
                    }
                }
                
                # Show expiration for exemptions
                if ($resource.expiresOn) {
                    $expiresLine = "$($prefix)  • Expires: $($resource.expiresOn.ToString('yyyy-MM-dd'))"
                    Write-Host $expiresLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $expiresLine
                    }
                }
                
                # Show status for exemptions (expired, expiring soon, etc.)
                if ($resource.status -and $resource.status -ne 'active') {
                    $statusLine = "$($prefix)  • Status: $($resource.status)"
                    Write-Host $statusLine -ForegroundColor $statusColors.warning
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $statusLine
                    }
                }
            }
            # For new operations without diffs, show basic info
            elseif ($resource.scope) {
                $scopeLine = "$($prefix)  • Scope: $($resource.scope)"
                Write-Host $scopeLine -ForegroundColor $statusColors.info
                if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                    $Global:epacInfoStream += $scopeLine
                }
            }
            
            # For new resources, show the JSON that will be applied
            if ($Operation -eq "new" -and $Granularity -ne "summary") {
                # Convert to JSON and display
                try {
                    # Create a temporary object excluding internal properties for clean JSON output
                    $tempObject = $resource.PSObject.Copy()
                    
                    # Remove internal tracking properties
                    $propsToRemove = @('diff', 'identityChanges', 'identityStatus')
                    foreach ($propToRemove in $propsToRemove) {
                        if ($tempObject.PSObject.Properties[$propToRemove]) {
                            $tempObject.PSObject.Properties.Remove($propToRemove)
                        }
                    }
                    
                    # Convert directly to JSON for clean output
                    $jsonOutput = $tempObject | ConvertTo-Json -Depth 100 -Compress:$false
                    $jsonLines = $jsonOutput -split "`n"
                    
                    $jsonHeaderLine = "$($prefix)  • JSON to be applied:"
                    Write-Host $jsonHeaderLine -ForegroundColor $statusColors.info
                    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                        $Global:epacInfoStream += $jsonHeaderLine
                    }
                    
                    foreach ($jsonLine in $jsonLines) {
                        $formattedLine = "$($prefix)    $jsonLine"
                        Write-Host $formattedLine -ForegroundColor $statusColors.skip
                        if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
                            $Global:epacInfoStream += $formattedLine
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to convert resource to JSON: $_"
                }
            }
        }
        
        Write-Host ""
    }
}

function Normalize-JsonForComparison {
    <#
    .SYNOPSIS
    Normalizes JSON structures by sorting arrays and object properties for better comparison.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Object
    )
    
    if ($null -eq $Object) {
        return $null
    }
    
    if ($Object -is [array]) {
        # Sort array elements if they're objects with a sortable key
        $normalized = @()
        foreach ($item in $Object) {
            $normalized += Normalize-JsonForComparison -Object $item
        }
        
        # Try to sort by common key properties
        if ($normalized.Count -gt 0 -and ($normalized[0] -is [hashtable] -or $normalized[0] -is [PSCustomObject])) {
            $sortKey = $null
            foreach ($key in @('value', 'name', 'id', 'kind', 'type')) {
                if ($normalized[0] -is [hashtable] -and $normalized[0].ContainsKey($key)) {
                    $sortKey = $key
                    break
                }
                elseif ($normalized[0] -is [PSCustomObject] -and (Get-Member -InputObject $normalized[0] -Name $key -MemberType NoteProperty)) {
                    $sortKey = $key
                    break
                }
            }
            
            if ($sortKey) {
                $normalized = $normalized | Sort-Object -Property $sortKey
            }
        }
        
        return $normalized
    }
    
    if ($Object -is [hashtable]) {
        $normalized = @{}
        foreach ($key in ($Object.Keys | Sort-Object)) {
            $normalized[$key] = Normalize-JsonForComparison -Object $Object[$key]
        }
        return $normalized
    }
    
    if ($Object -is [PSCustomObject]) {
        $properties = $Object | Get-Member -MemberType NoteProperty | Sort-Object Name
        $normalized = [PSCustomObject]@{}
        foreach ($prop in $properties) {
            $normalized | Add-Member -MemberType NoteProperty -Name $prop.Name -Value (Normalize-JsonForComparison -Object $Object.($prop.Name))
        }
        return $normalized
    }
    
    return $Object
}

function Get-ObjectDiff {
    <#
    .SYNOPSIS
    Recursively compares two objects and generates diff lines.
    #>
    param(
        $Before,
        $After,
        [int] $BaseIndent,
        [string] $PropertyPath = ""
    )
    
    $result = @()
    $indentStr = " " * $BaseIndent
    
    # Handle simple value differences
    if ($null -eq $Before -and $null -eq $After) {
        return @()
    }
    
    # If types differ or one is null, show full replacement
    if (($null -eq $Before) -or ($null -eq $After) -or $Before.GetType() -ne $After.GetType()) {
        if ($null -ne $Before) {
            $beforeJson = $Before | ConvertTo-Json -Depth 100 -Compress
            $result += "$indentStr- $beforeJson"
        }
        if ($null -ne $After) {
            $afterJson = $After | ConvertTo-Json -Depth 100 -Compress
            $result += "$indentStr+ $afterJson"
        }
        return $result
    }
    
    # Handle arrays - compare elements
    if ($Before -is [array] -and $After -is [array]) {
        $beforeSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$Before)
        $afterSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$After)
        
        # Removed items
        foreach ($item in ($Before | Sort-Object)) {
            if (!$afterSet.Contains($item)) {
                $result += "$indentStr-       `"$item`","
            }
        }
        
        # Added items
        foreach ($item in ($After | Sort-Object)) {
            if (!$beforeSet.Contains($item)) {
                $result += "$indentStr+       `"$item`","
            }
        }
        
        return $result
    }
    
    # Handle objects - compare properties
    if ($Before -is [hashtable] -or $Before -is [PSCustomObject]) {
        $beforeProps = if ($Before -is [hashtable]) { $Before.Keys } else { ($Before | Get-Member -MemberType NoteProperty).Name }
        $afterProps = if ($After -is [hashtable]) { $After.Keys } else { ($After | Get-Member -MemberType NoteProperty).Name }
        
        $allProps = ($beforeProps + $afterProps | Select-Object -Unique | Sort-Object)
        
        foreach ($prop in $allProps) {
            $beforeVal = if ($Before -is [hashtable]) { $Before[$prop] } else { $Before.$prop }
            $afterVal = if ($After -is [hashtable]) { $After[$prop] } else { $After.$prop }
            
            $beforeJson = if ($null -ne $beforeVal) { $beforeVal | ConvertTo-Json -Depth 100 -Compress } else { "null" }
            $afterJson = if ($null -ne $afterVal) { $afterVal | ConvertTo-Json -Depth 100 -Compress } else { "null" }
            
            if ($beforeJson -ne $afterJson) {
                # Check if it's an array we can diff element-by-element
                if ($beforeVal -is [array] -and $afterVal -is [array] -and 
                    $beforeVal.Count -gt 0 -and $afterVal.Count -gt 0 -and
                    $beforeVal[0] -is [string] -and $afterVal[0] -is [string]) {
                    # Recursively diff the array
                    $arrayDiff = Get-ObjectDiff -Before $beforeVal -After $afterVal -BaseIndent $BaseIndent
                    if ($arrayDiff.Count -gt 0) {
                        $result += $arrayDiff
                    }
                }
                else {
                    # Show property-level diff
                    if ($null -ne $beforeVal) {
                        $result += "$indentStr- `"$prop`": $beforeJson"
                    }
                    if ($null -ne $afterVal) {
                        $result += "$indentStr+ `"$prop`": $afterJson"
                    }
                }
            }
        }
        
        return $result
    }
    
    # Simple values - compare directly
    $beforeJson = $Before | ConvertTo-Json -Depth 100 -Compress
    $afterJson = $After | ConvertTo-Json -Depth 100 -Compress
    
    if ($beforeJson -ne $afterJson) {
        $result += "$indentStr- $beforeJson"
        $result += "$indentStr+ $afterJson"
    }
    
    return $result
}

function Get-BlockAwareDiff {
    <#
    .SYNOPSIS
    Creates a block-aware diff for arrays, comparing elements as complete objects.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $BeforeObject,
        
        [Parameter(Mandatory = $true)]
        $AfterObject,
        
        [int] $BaseIndent
    )
    
    $result = @()
    $indentStr = " " * $BaseIndent
    
    # If both are arrays, do block-aware comparison
    if ($BeforeObject -is [array] -and $AfterObject -is [array]) {
        # Create lookup by key for matching
        $beforeByKey = @{}
        $afterByKey = @{}
        
        foreach ($item in $BeforeObject) {
            if ($item -is [hashtable] -or $item -is [PSCustomObject]) {
                # Find a key to identify this object
                $keyValue = $null
                foreach ($keyProp in @('value', 'name', 'id', 'displayName')) {
                    if ($item -is [hashtable] -and $item.ContainsKey($keyProp)) {
                        $keyValue = $item[$keyProp]
                        break
                    }
                    elseif ($item -is [PSCustomObject] -and (Get-Member -InputObject $item -Name $keyProp -MemberType NoteProperty)) {
                        $keyValue = $item.$keyProp
                        break
                    }
                }
                if ($keyValue) {
                    $beforeByKey[$keyValue] = $item
                }
            }
        }
        
        foreach ($item in $AfterObject) {
            if ($item -is [hashtable] -or $item -is [PSCustomObject]) {
                $keyValue = $null
                foreach ($keyProp in @('value', 'name', 'id', 'displayName')) {
                    if ($item -is [hashtable] -and $item.ContainsKey($keyProp)) {
                        $keyValue = $item[$keyProp]
                        break
                    }
                    elseif ($item -is [PSCustomObject] -and (Get-Member -InputObject $item -Name $keyProp -MemberType NoteProperty)) {
                        $keyValue = $item.$keyProp
                        break
                    }
                }
                if ($keyValue) {
                    $afterByKey[$keyValue] = $item
                }
            }
        }
        
        # Show removed items
        foreach ($key in ($beforeByKey.Keys | Sort-Object)) {
            if (!$afterByKey.ContainsKey($key)) {
                $json = $beforeByKey[$key] | ConvertTo-Json -Depth 100
                $lines = $json -split "`r?`n"
                foreach ($line in $lines) {
                    if ($line.Trim()) {
                        $result += "$indentStr- $line"
                    }
                }
            }
        }
        
        # Show added items
        foreach ($key in ($afterByKey.Keys | Sort-Object)) {
            if (!$beforeByKey.ContainsKey($key)) {
                $json = $afterByKey[$key] | ConvertTo-Json -Depth 100
                $lines = $json -split "`r?`n"
                foreach ($line in $lines) {
                    if ($line.Trim()) {
                        $result += "$indentStr+ $line"
                    }
                }
            }
        }
        
        # Show modified items (exist in both but different)
        foreach ($key in ($beforeByKey.Keys | Sort-Object)) {
            if ($afterByKey.ContainsKey($key)) {
                $beforeJson = $beforeByKey[$key] | ConvertTo-Json -Depth 100 -Compress
                $afterJson = $afterByKey[$key] | ConvertTo-Json -Depth 100 -Compress
                
                if ($beforeJson -ne $afterJson) {
                    # Show object header
                    $result += "$indentStr  {"
                    
                    # Get property-level diffs
                    $beforeItem = $beforeByKey[$key]
                    $afterItem = $afterByKey[$key]
                    
                    # Compare each property
                    $beforeProps = if ($beforeItem -is [hashtable]) { $beforeItem.Keys } else { ($beforeItem | Get-Member -MemberType NoteProperty).Name }
                    $afterProps = if ($afterItem -is [hashtable]) { $afterItem.Keys } else { ($afterItem | Get-Member -MemberType NoteProperty).Name }
                    $allProps = ($beforeProps + $afterProps | Select-Object -Unique | Sort-Object)
                    
                    foreach ($prop in $allProps) {
                        $beforeVal = if ($beforeItem -is [hashtable]) { $beforeItem[$prop] } else { $beforeItem.$prop }
                        $afterVal = if ($afterItem -is [hashtable]) { $afterItem[$prop] } else { $afterItem.$prop }
                        
                        $beforePropJson = if ($null -ne $beforeVal) { $beforeVal | ConvertTo-Json -Depth 100 -Compress } else { "null" }
                        $afterPropJson = if ($null -ne $afterVal) { $afterVal | ConvertTo-Json -Depth 100 -Compress } else { "null" }
                        
                        if ($beforePropJson -ne $afterPropJson) {
                            # Special handling for arrays of strings (like the "in" array)
                            if ($beforeVal -is [array] -and $afterVal -is [array]) {
                                $result += "$indentStr    `"$prop`": {"
                                $result += "$indentStr      `"kind`": `"policyDefinitionReferenceId`","
                                $result += "$indentStr      `"in`": ["
                                
                                # Compare array elements
                                $beforeSet = [System.Collections.Generic.HashSet[string]]::new()
                                $afterSet = [System.Collections.Generic.HashSet[string]]::new()
                                
                                if ($beforeVal -is [array]) {
                                    foreach ($item in $beforeVal) { [void]$beforeSet.Add($item) }
                                }
                                if ($afterVal -is [array]) {
                                    foreach ($item in $afterVal) { [void]$afterSet.Add($item) }
                                }
                                
                                # Removed items
                                foreach ($item in ($beforeVal | Sort-Object)) {
                                    if (!$afterSet.Contains($item)) {
                                        $result += "$indentStr-       `"$item`","
                                    }
                                }
                                
                                # Added items  
                                foreach ($item in ($afterVal | Sort-Object)) {
                                    if (!$beforeSet.Contains($item)) {
                                        $result += "$indentStr+       `"$item`","
                                    }
                                }
                                
                                $result += "$indentStr      ]"
                                $result += "$indentStr    },"
                            }
                            elseif ($prop -eq 'selectors') {
                                # Handle selectors object specially
                                $result += "$indentStr    `"selectors`": {"
                                
                                $selectorProps = if ($beforeVal -is [hashtable]) { $beforeVal.Keys } else { ($beforeVal | Get-Member -MemberType NoteProperty).Name }
                                foreach ($sProp in ($selectorProps | Sort-Object)) {
                                    $sBeforeVal = if ($beforeVal -is [hashtable]) { $beforeVal[$sProp] } else { $beforeVal.$sProp }
                                    $sAfterVal = if ($afterVal -is [hashtable]) { $afterVal[$sProp] } else { $afterVal.$sProp }
                                    
                                    $sBeforeJson = if ($null -ne $sBeforeVal) { $sBeforeVal | ConvertTo-Json -Depth 100 -Compress } else { "null" }
                                    $sAfterJson = if ($null -ne $sAfterVal) { $sAfterVal | ConvertTo-Json -Depth 100 -Compress } else { "null" }
                                    
                                    if ($sBeforeJson -eq $sAfterJson) {
                                        # Unchanged selector property
                                        $result += "$indentStr      `"$sProp`": $sBeforeJson,"
                                    }
                                    else {
                                        # Changed - for arrays, show element diffs
                                        if ($sBeforeVal -is [array] -and $sAfterVal -is [array]) {
                                            $result += "$indentStr      `"$sProp`": ["
                                            
                                            $sBeforeSet = [System.Collections.Generic.HashSet[string]]::new()
                                            $sAfterSet = [System.Collections.Generic.HashSet[string]]::new()
                                            
                                            foreach ($item in $sBeforeVal) { [void]$sBeforeSet.Add($item) }
                                            foreach ($item in $sAfterVal) { [void]$sAfterSet.Add($item) }
                                            
                                            # Removed
                                            foreach ($item in ($sBeforeVal | Sort-Object)) {
                                                if (!$sAfterSet.Contains($item)) {
                                                    $result += "$indentStr-       `"$item`","
                                                }
                                            }
                                            
                                            # Added
                                            foreach ($item in ($sAfterVal | Sort-Object)) {
                                                if (!$sBeforeSet.Contains($item)) {
                                                    $result += "$indentStr+       `"$item`","
                                                }
                                            }
                                            
                                            $result += "$indentStr      ]"
                                        }
                                    }
                                }
                                
                                $result += "$indentStr    },"
                            }
                            else {
                                # Other changed properties
                                $result += "$indentStr-   `"$prop`": $beforePropJson,"
                                $result += "$indentStr+   `"$prop`": $afterPropJson,"
                            }
                        }
                        else {
                            # Unchanged property
                            $propJson = $beforePropJson
                            if ($beforeVal -is [hashtable] -or $beforeVal -is [PSCustomObject]) {
                                $propJson = $beforeVal | ConvertTo-Json -Depth 100
                                $propLines = $propJson -split "`r?`n"
                                $result += "$indentStr    `"$prop`": $($propLines[0])"
                                for ($i = 1; $i -lt $propLines.Count; $i++) {
                                    $result += "$indentStr    $($propLines[$i])"
                                }
                            }
                            else {
                                $result += "$indentStr    `"$prop`": $propJson,"
                            }
                        }
                    }
                    
                    $result += "$indentStr  }"
                }
            }
        }
        
        return $result -join "`n"
    }
    
    # Fallback to simple line-by-line diff
    $beforeJson = $BeforeObject | ConvertTo-Json -Depth 100
    $afterJson = $AfterObject | ConvertTo-Json -Depth 100
    
    $beforeLines = ($beforeJson -split "`r?`n") | Where-Object { $_.Trim() }
    $afterLines = ($afterJson -split "`r?`n") | Where-Object { $_.Trim() }
    
    foreach ($line in $beforeLines) {
        $result += "$indentStr- $line"
    }
    foreach ($line in $afterLines) {
        $result += "$indentStr+ $line"
    }
    
    return $result -join "`n"
}

function Format-DiffEntry {
    <#
    .SYNOPSIS
    Formats a single diff entry for display.
    
    .DESCRIPTION
    Converts a diff entry object into formatted text with appropriate color coding.
    Handles sensitive value masking and different granularity levels.
    
    .PARAMETER DiffEntry
    The diff entry object to format
    
    .PARAMETER Granularity
    Diff detail level: standard, detailed, or verbose
    
    .PARAMETER Indent
    Number of spaces to indent the output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $DiffEntry,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("standard", "detailed", "verbose")]
        [string] $Granularity = "standard",
        
        [Parameter(Mandatory = $false)]
        [int] $Indent = 4
    )
    
    $theme = Get-OutputTheme
    $statusColors = $theme.colors.status
    $prefix = " " * $Indent
    
    # Determine color based on operation
    $color = switch ($DiffEntry.op) {
        "add" { $statusColors.success }
        "remove" { $statusColors.error }
        "replace" { $statusColors.update }
        default { $statusColors.info }
    }
    
    # Determine symbol
    $symbol = switch ($DiffEntry.op) {
        "add" { "+" }
        "remove" { "-" }
        "replace" { "~" }
        default { "•" }
    }
    
    # Format value for display
    $isSensitive = Test-IsSensitivePath -Path $DiffEntry.path
    
    # Check if we're dealing with complex structures that need line-by-line diff
    $useLineByLineDiff = $false
    if ($Granularity -ne "standard" -and !$isSensitive -and $DiffEntry.op -eq "replace") {
        if (($DiffEntry.before -is [array] -or $DiffEntry.before -is [hashtable] -or $DiffEntry.before -is [PSCustomObject]) -and
            ($DiffEntry.after -is [array] -or $DiffEntry.after -is [hashtable] -or $DiffEntry.after -is [PSCustomObject])) {
            $useLineByLineDiff = $true
        }
    }
    
    if ($useLineByLineDiff) {
        # Normalize structures before comparison to handle ordering differences
        $normalizedBefore = Normalize-JsonForComparison -Object $DiffEntry.before
        $normalizedAfter = Normalize-JsonForComparison -Object $DiffEntry.after
        
        # Build terraform-style block-aware diff output
        $blockDiff = Get-BlockAwareDiff -BeforeObject $normalizedBefore -AfterObject $normalizedAfter -BaseIndent ($Indent + 2)
        
        $text = "$prefix$symbol $($DiffEntry.path):`n$blockDiff"
        
        return @{
            text  = $text
            color = $statusColors.update
        }
    }
    
    # Standard formatting for simple values
    $beforeValue = if ($isSensitive) { "(sensitive)" } else { ConvertTo-DisplayValue -Value $DiffEntry.before -Granularity $Granularity }
    $afterValue = if ($isSensitive) { "(sensitive)" } else { ConvertTo-DisplayValue -Value $DiffEntry.after -Granularity $Granularity }
    
    # Build output text
    $text = switch ($DiffEntry.op) {
        "add" {
            "$prefix$symbol $($DiffEntry.path): $afterValue"
        }
        "remove" {
            "$prefix$symbol $($DiffEntry.path): $beforeValue"
        }
        "replace" {
            if ($isSensitive) {
                "$prefix$symbol $($DiffEntry.path): (sensitive) changed"
            }
            else {
                "$prefix$symbol $($DiffEntry.path): $beforeValue → $afterValue"
            }
        }
        default {
            "$prefix$symbol $($DiffEntry.path): changed"
        }
    }
    
    return @{
        text  = $text
        color = $color
    }
}

function ConvertTo-DisplayValue {
    <#
    .SYNOPSIS
    Converts a value to a display-friendly string.
    
    .DESCRIPTION
    Handles different value types (null, boolean, number, string, object, array) and formats them appropriately.
    Respects granularity level for complex objects.
    
    .PARAMETER Value
    The value to convert
    
    .PARAMETER Granularity
    Diff detail level: standard, detailed, or verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Value,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("standard", "detailed", "verbose")]
        [string] $Granularity = "standard"
    )
    
    if ($null -eq $Value) {
        return "null"
    }
    
    if ($Value -is [bool]) {
        return $Value.ToString().ToLower()
    }
    
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) {
        return $Value.ToString()
    }
    
    if ($Value -is [string]) {
        # Truncate very long strings with ellipsis for readability
        if ($Value.Length -gt 150 -and $Granularity -eq "standard") {
            $truncated = $Value.Substring(0, 147)
            return "`"$truncated...(+$($Value.Length - 147) chars)`""
        }
        return "`"$Value`""
    }
    
    if ($Value -is [array]) {
        if ($Granularity -eq "standard" -and $Value.Count -gt 5) {
            # Show first few items with count
            $preview = $Value | Select-Object -First 3 | ForEach-Object { ConvertTo-DisplayValue -Value $_ -Granularity $Granularity }
            return "[$($preview -join ', '), ...(+$($Value.Count - 3) more)]"
        }
        elseif ($Granularity -ne "standard" -and $Value.Count -gt 0) {
            # Use pretty-printed JSON for detailed/verbose to match terraform style
            $json = $Value | ConvertTo-Json -Depth 100
            # Indent each line for better alignment
            $lines = $json -split '`r?`n'
            return ($lines -join "`n        ")
        }
        else {
            $items = $Value | ForEach-Object { ConvertTo-DisplayValue -Value $_ -Granularity $Granularity }
            return "[$($items -join ', ')]"
        }
    }
    
    if ($Value -is [hashtable] -or $Value -is [PSCustomObject]) {
        if ($Granularity -eq "standard") {
            # Count properties for context
            $propCount = if ($Value -is [hashtable]) { $Value.Keys.Count } else { ($Value | Get-Member -MemberType NoteProperty).Count }
            return "{Object with $propCount properties}"
        }
        else {
            # Use pretty-printed JSON for detailed/verbose
            $json = $Value | ConvertTo-Json -Depth 100
            $lines = $json -split '`r?`n'
            return ($lines -join "`n        ")
        }
    }
    
    return $Value.ToString()
}

function Write-ModernDiffSummary {
    <#
    .SYNOPSIS
    Writes a summary of all changes with count by type.
    
    .DESCRIPTION
    Provides an overview of changes across all resource types.
    Useful for quick assessment before detailed diff review.
    
    .PARAMETER PolicyPlan
    The policy deployment plan
    
    .PARAMETER RolesPlan
    The roles deployment plan
    
    .PARAMETER Indent
    Number of spaces to indent the output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable] $PolicyPlan,
        
        [Parameter(Mandatory = $false)]
        [hashtable] $RolesPlan,
        
        [Parameter(Mandatory = $false)]
        [int] $Indent = 2
    )
    
    $theme = Get-OutputTheme
    $prefix = " " * $Indent
    
    Write-ModernSection -Title "Change Summary" -Indent 0
    
    $totalChanges = 0
    $changesByType = @{}
    
    # Count policy changes
    if ($PolicyPlan) {
        foreach ($resourceType in @("policies", "policySets", "assignments", "exemptions")) {
            if ($PolicyPlan.$resourceType) {
                foreach ($action in @("new", "update", "replace", "delete")) {
                    if ($PolicyPlan.$resourceType.$action) {
                        $count = $PolicyPlan.$resourceType.$action.Count
                        if ($count -gt 0) {
                            $totalChanges += $count
                            $key = "$resourceType.$action"
                            $changesByType[$key] = $count
                        }
                    }
                }
            }
        }
    }
    
    # Count role changes
    if ($RolesPlan) {
        if ($RolesPlan.added -and $RolesPlan.added.Count -gt 0) {
            $totalChanges += $RolesPlan.added.Count
            $changesByType["roles.added"] = $RolesPlan.added.Count
        }
        if ($RolesPlan.removed -and $RolesPlan.removed.Count -gt 0) {
            $totalChanges += $RolesPlan.removed.Count
            $changesByType["roles.removed"] = $RolesPlan.removed.Count
        }
    }
    
    if ($totalChanges -eq 0) {
        Write-ModernStatus -Message "No changes detected" -Status "info" -Indent $Indent
    }
    else {
        Write-ModernStatus -Message "$totalChanges total changes across all resource types" -Status "info" -Indent $Indent
        
        foreach ($entry in $changesByType.GetEnumerator() | Sort-Object Key) {
            Write-ModernStatus -Message "$($entry.Value) $($entry.Key)" -Status "info" -Indent ($Indent + 2)
        }
    }
}
