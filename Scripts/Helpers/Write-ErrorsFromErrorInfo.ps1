function Write-ErrorsFromErrorInfo {
    [CmdletBinding()]
    param (
        [hashtable] $ErrorInfo
    )
    if ($ErrorInfo.hasErrors) {
        Write-Host -ForegroundColor Red "Errors in file '$($ErrorInfo.fileName)' list of $($ErrorInfo.errorsInFile):'"
        foreach ($errorString in $ErrorInfo.errorStrings) {
            Write-Host -ForegroundColor DarkYellow "  $errorString"
        }
        Write-Host -ForegroundColor Red "End of errors in file '$($ErrorInfo.fileName)' list of $($ErrorInfo.errorsInFile)."
    }
}
