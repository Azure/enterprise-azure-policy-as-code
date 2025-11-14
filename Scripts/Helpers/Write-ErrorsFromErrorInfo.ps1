function Write-ErrorsFromErrorInfo {
    [CmdletBinding()]
    param (
        [hashtable] $ErrorInfo
    )
    if ($ErrorInfo.hasErrors) {
        Write-Information "File '$($ErrorInfo.fileName)' has $($ErrorInfo.errorsInFile) errors:"
        foreach ($errorString in $ErrorInfo.errorStrings) {
            Write-Information "    $errorString" -InformationAction Continue
        }
        Write-Error "File '$($ErrorInfo.fileName)' with $($ErrorInfo.errorsInFile) errors (end of list)."
    }
}
