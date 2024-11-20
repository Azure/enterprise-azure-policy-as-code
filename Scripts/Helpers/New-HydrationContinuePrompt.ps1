function New-HydrationContinuePrompt {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $Interactive,
        [Parameter(Mandatory = $false)]
        [int]
        $SleepTime = 10
    )
    Write-Host "`n"
    if ($Interactive) {
        $message = "Press any key to continue..."
        Write-Host $message -ForegroundColor Yellow
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Remove-Variable x
        Remove-Variable message
    }`
        else {
        $message = "Continuing in $($Sleeptime.ToString()) seconds..."
        Write-Host $message -ForegroundColor Yellow
        Start-Sleep -Seconds $SleepTime
    }
    Write-Host "`n`n"
}