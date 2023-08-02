function Add-ErrorMessage {
    [CmdletBinding()]
    param (
        [string] $ErrorString,
        [int] $EntryNumber = -1,
        [hashtable] $ErrorInfo
    )
    
    if ($EntryNumber -ne -1) {
        if ($ErrorInfo.currentEntryNumber -ne $EntryNumber) {
            $ErrorInfo.errorStrings.Add("- Entry number $($EntryNumber):")
        }
        $ErrorInfo.errorStrings.Add("  - $ErrorString")
    }
    else {
        $ErrorInfo.errorStrings.Add("- $ErrorString")
    }
    $ErrorInfo.errorsInFile++
    $ErrorInfo.hasErrors = $true
    $ErrorInfo.currentEntryNumber = $EntryNumber
}
