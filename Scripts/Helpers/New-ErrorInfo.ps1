function New-ErrorInfo {
    [CmdletBinding()]
    param (
        [string] $FileName
    )
    $errorInfo = @{
        errorStrings       = [System.Collections.ArrayList]::new()
        errorsInFile       = 0
        currentEntryNumber = -1
        hasErrors          = $false
        fileName           = $FileName
    }
    $errorInfo
}
