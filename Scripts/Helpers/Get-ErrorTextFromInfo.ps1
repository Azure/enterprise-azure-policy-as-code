function Get-ErrorTextFromInfo {
    [CmdletBinding()]
    param (
        [hashtable] $ErrorInfo
    )
    if ($ErrorInfo.hasErrors) {
        $bodyText = $ErrorInfo.errorStrings -join "`n`r"
        $errorText = "'$($ErrorInfo.fileName)' has $($ErrorInfo.errorsInFile) errors:`n`r$bodyText"
        $errorText
    }
    else {
        "No errors found"
    }
}
