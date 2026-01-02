function Write-ModernDiff {
    <#
    .SYNOPSIS
    Renders Terraform-style diff output for resource changes.
    
    .DESCRIPTION
    Displays detailed property-level changes with before/after values using Terraform-style visualization.
    Supports multiple granularity levels: standard, detailed, verbose.
    
    .PARAMETER ResourceType
    The type of resource (e.g., "Policy", "PolicySet", "Assignment")
    
    .PARAMETER Resources
    Hashtable of resources with diff arrays attached
    
    .PARAMETER Granularity
    Diff detail level: standard, detailed, or verbose
    
    .PARAMETER Indent
    Number of spaces to indent the output
    
    .EXAMPLE
    Write-ModernDiff -ResourceType "Assignments" -Resources $plan.assignments.update -Granularity "standard" -Indent 2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResourceType,
        
        [Parameter(Mandatory = $true)]
        [hashtable] $Resources,
        
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
        
        # Display resource header
        $displayName = if ($resource.displayName) { $resource.displayName } elseif ($resource.name) { $resource.name } else { $resourceId }
        $headerLine = "$prefix⭮ Update: $displayName"
        Write-Host $headerLine -ForegroundColor $statusColors.update
        
        if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
            $Global:epacInfoStream += $headerLine
        }
        
        # Display diffs if available
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
        
        Write-Host ""
    }
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
    
    # Check if value is sensitive
    $isSensitive = Test-IsSensitivePath -Path $DiffEntry.path
    
    # Format value for display
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
        return "`"$Value`""
    }
    
    if ($Value -is [array]) {
        if ($Granularity -eq "standard" -and $Value.Count -gt 3) {
            return "[Array with $($Value.Count) items]"
        }
        else {
            $items = $Value | ForEach-Object { ConvertTo-DisplayValue -Value $_ -Granularity $Granularity }
            return "[$($items -join ', ')]"
        }
    }
    
    if ($Value -is [hashtable] -or $Value -is [PSCustomObject]) {
        if ($Granularity -eq "standard") {
            return "{Object}"
        }
        else {
            return ($Value | ConvertTo-Json -Compress -Depth 2)
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
