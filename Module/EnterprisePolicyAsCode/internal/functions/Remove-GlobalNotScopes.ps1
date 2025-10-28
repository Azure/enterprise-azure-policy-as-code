function Remove-GlobalNotScopes {
    [CmdletBinding()]
    param (
        $AssignmentNotScopes,
        $GlobalNotScopes
    )
    if ($null -eq $AssignmentNotScopes -or $AssignmentNotScopes.Count -eq 0) {
        $null
    }
    elseif ($GlobalNotScopes.Count -eq 0) {
        Write-Output $AssignmentNotScopes -NoEnumerate
    }
    else {
        $assignmentLevelNotScopes = [System.Collections.ArrayList]::new()
        foreach ($assignmentNotScope in $AssignmentNotScopes) {
            $found = $false
            foreach ($globalNotScope in $GlobalNotScopes) {
                if ($assignmentNotScope -like $globalNotScope) {
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                $null = $assignmentLevelNotScopes.Add($assignmentNotScope)
            }
        }
        if ($assignmentLevelNotScopes.Count -eq 0) {
            $null
        }
        else {
            Write-Output $assignmentLevelNotScopes -NoEnumerate
        }
    }
}
