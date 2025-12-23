function Write-PolicyChangeLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $LogFilePath,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("New", "Update", "Replace", "Delete")]
        [string] $Action,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Policy", "PolicySet", "Assignment", "Exemption", "RoleAssignment")]
        [string] $ResourceType,
        
        [Parameter(Mandatory = $true)]
        [string] $Name,
        
        [Parameter(Mandatory = $false)]
        [string] $DisplayName,
        
        [Parameter(Mandatory = $false)]
        [hashtable] $Changes,
        
        [Parameter(Mandatory = $false)]
        [object] $OldValue,
        
        [Parameter(Mandatory = $false)]
        [object] $NewValue
    )
    
    # Ensure log file exists
    if (!(Test-Path $LogFilePath)) {
        $null = New-Item -Path $LogFilePath -ItemType File -Force
        $header = @"
================================================================================
EPAC Policy Changes - Detailed Log
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
================================================================================

"@
        $header | Set-Content -Path $LogFilePath -Encoding UTF8
    }
    
    # Build log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $separator = "-" * 80
    
    $logEntry = @"

$separator
[$timestamp] $Action - $ResourceType
Name: $Name
"@
    
    if ($DisplayName) {
        $logEntry += "`nDisplay Name: $DisplayName"
    }
    
    # Add action-specific details
    switch ($Action) {
        "New" {
            $logEntry += "`n`nComplete Definition (NEW):"
            if ($NewValue) {
                $logEntry += "`n" + ($NewValue | ConvertTo-Json -Depth 100)
            }
        }
        "Delete" {
            $logEntry += "`n`nComplete Definition (DELETED):"
            if ($OldValue) {
                $logEntry += "`n" + ($OldValue | ConvertTo-Json -Depth 100)
            }
        }
        "Update" {
            if ($Changes -and $Changes.Count -gt 0) {
                $logEntry += "`n`nChanges:"
                foreach ($changeKey in $Changes.Keys) {
                    $change = $Changes[$changeKey]
                    
                    # Check if this is a complex object with nested differences
                    if ($change.ContainsKey('differences') -and $change.differences -is [hashtable] -and $change.differences.Count -gt 0) {
                        $logEntry += "`n`n  Field: $changeKey (complex object - showing only changed properties)"
                        foreach ($diffPath in ($change.differences.Keys | Sort-Object)) {
                            $diff = $change.differences[$diffPath]
                            $logEntry += "`n    $diffPath"
                            
                            if ($diff.ContainsKey('old')) {
                                $oldValue = $diff.old
                                if ($null -eq $oldValue -or $oldValue -eq '') {
                                    $oldValueText = '(empty)'
                                }
                                elseif ($oldValue -is [hashtable] -or $oldValue -is [System.Collections.IDictionary]) {
                                    $oldValueText = ($oldValue | ConvertTo-Json -Compress -Depth 10)
                                }
                                else {
                                    $oldValueText = $oldValue
                                }
                                $logEntry += "`n      Old: $oldValueText"
                            }
                            if ($diff.ContainsKey('new')) {
                                $newValue = $diff.new
                                if ($null -eq $newValue -or $newValue -eq '') {
                                    $newValueText = '(empty)'
                                }
                                elseif ($newValue -is [hashtable] -or $newValue -is [System.Collections.IDictionary]) {
                                    $newValueText = ($newValue | ConvertTo-Json -Compress -Depth 10)
                                }
                                else {
                                    $newValueText = $newValue
                                }
                                $logEntry += "`n      New: $newValueText"
                            }
                            if ($diff.ContainsKey('change')) {
                                $logEntry += "`n      Change: $($diff.change)"
                            }
                        }
                    }
                    else {
                        # Simple field change
                        $logEntry += "`n`n  Field: $changeKey"
                        
                        # Always show old value, even if empty or null
                        if ($change.ContainsKey('old')) {
                            $oldValueText = if ($null -eq $change.old -or $change.old -eq '') { '(empty)' } else { $change.old }
                            $logEntry += "`n  Old Value: $oldValueText"
                        }
                        # Always show new value, even if empty or null
                        if ($change.ContainsKey('new')) {
                            $newValueText = if ($null -eq $change.new -or $change.new -eq '') { '(empty)' } else { $change.new }
                            $logEntry += "`n  New Value: $newValueText"
                        }
                    }
                }
            }
        }
        "Replace" {
            $logEntry += "`n`nREPLACE (Breaking Change)"
            if ($Changes -and $Changes.Count -gt 0) {
                $logEntry += "`n`nChanges:"
                foreach ($changeKey in $Changes.Keys) {
                    $change = $Changes[$changeKey]
                    
                    # Check if this is a complex object with nested differences
                    if ($change.ContainsKey('differences') -and $change.differences -is [hashtable] -and $change.differences.Count -gt 0) {
                        $logEntry += "`n`n  Field: $changeKey (complex object - showing only changed properties)"
                        foreach ($diffPath in ($change.differences.Keys | Sort-Object)) {
                            $diff = $change.differences[$diffPath]
                            $logEntry += "`n    $diffPath"
                            
                            if ($diff.ContainsKey('old')) {
                                $oldValue = $diff.old
                                if ($null -eq $oldValue -or $oldValue -eq '') {
                                    $oldValueText = '(empty)'
                                }
                                elseif ($oldValue -is [hashtable] -or $oldValue -is [System.Collections.IDictionary]) {
                                    $oldValueText = ($oldValue | ConvertTo-Json -Compress -Depth 10)
                                }
                                else {
                                    $oldValueText = $oldValue
                                }
                                $logEntry += "`n      Old: $oldValueText"
                            }
                            if ($diff.ContainsKey('new')) {
                                $newValue = $diff.new
                                if ($null -eq $newValue -or $newValue -eq '') {
                                    $newValueText = '(empty)'
                                }
                                elseif ($newValue -is [hashtable] -or $newValue -is [System.Collections.IDictionary]) {
                                    $newValueText = ($newValue | ConvertTo-Json -Compress -Depth 10)
                                }
                                else {
                                    $newValueText = $newValue
                                }
                                $logEntry += "`n      New: $newValueText"
                            }
                            if ($diff.ContainsKey('change')) {
                                $logEntry += "`n      Change: $($diff.change)"
                            }
                        }
                    }
                    else {
                        # Simple field change
                        $logEntry += "`n`n  Field: $changeKey"
                        
                        # Always show old value, even if empty or null
                        if ($change.ContainsKey('old')) {
                            $oldValueText = if ($null -eq $change.old -or $change.old -eq '') { '(empty)' } else { $change.old }
                            $logEntry += "`n  Old Value: $oldValueText"
                        }
                        # Always show new value, even if empty or null
                        if ($change.ContainsKey('new')) {
                            $newValueText = if ($null -eq $change.new -or $change.new -eq '') { '(empty)' } else { $change.new }
                            $logEntry += "`n  New Value: $newValueText"
                        }
                    }
                }
            }
        }
    }
    
    $logEntry += "`n$separator`n"
    
    # Append to log file
    $logEntry | Out-File -FilePath $LogFilePath -Encoding UTF8 -Append -Force
}
