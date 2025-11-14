function Add-ErrorMessage {
    [CmdletBinding()]
    param (
        [string] $ErrorString,
        [int] $EntryNumber = -1,
        [hashtable] $ErrorInfo
    )
    
    if ($EntryNumber -ne -1) {
        $null = $ErrorInfo.errorStrings.Add("$($EntryNumber): $ErrorString")
    }
    else {
        $null = $ErrorInfo.errorStrings.Add("$ErrorString")
    }
    $ErrorInfo.errorsInFile++
    $ErrorInfo.hasErrors = $true
    $ErrorInfo.hasLocalErrors = $true
    $ErrorInfo.currentEntryNumber = $EntryNumber
}
