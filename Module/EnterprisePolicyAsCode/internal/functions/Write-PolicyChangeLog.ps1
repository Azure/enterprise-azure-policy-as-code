function Write-PolicyChangeLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $LogFilePath,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("New", "Update", "Replace", "Delete")]
        [string] $Action,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Policy", "PolicySet", "Assignment", "Exemption")]
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
                    $logEntry += "`n`n  Field: $changeKey"
                    
                    if ($null -ne $change.old) {
                        $logEntry += "`n  Old Value: $($change.old)"
                    }
                    if ($null -ne $change.new) {
                        $logEntry += "`n  New Value: $($change.new)"
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
                    $logEntry += "`n`n  Field: $changeKey"
                    
                    if ($null -ne $change.old) {
                        $logEntry += "`n  Old Value: $($change.old)"
                    }
                    if ($null -ne $change.new) {
                        $logEntry += "`n  New Value: $($change.new)"
                    }
                }
            }
        }
    }
    
    $logEntry += "`n$separator`n"
    
    # Append to log file
    $logEntry | Out-File -FilePath $LogFilePath -Encoding UTF8 -Append -Force
}
