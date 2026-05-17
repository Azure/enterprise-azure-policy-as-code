function Write-HydrationLogFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("newStage", "commandStart", "testStart", "testResult", "answerRequested", "answerSetProvided", "logEntryDataAsPresented")]
        [string]
        $EntryType,
        [Parameter(Mandatory = $true)]
        [string]
        $EntryData,
        [Parameter(Mandatory = $true)]
        [string]
        $LogFilePath,
        [Parameter(Mandatory = $false)]
        [switch]
        $UseUtc = $false,
        [string]
        [Parameter(Mandatory = $false)]
        [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")]
        $ForegroundColor,
        [Parameter(Mandatory = $false)]
        [switch]
        $Silent

    )

    # $UseUtc defaults to $false, rather than $null, because it affects the ability to use the -switch:binary functionality.
    $timeStamp = Get-Date -asUTC:$UseUtc -format yyyy-MM-dd_hh:mm:ss
    if (!(Test-Path $LogFilePath)) {
        $null = New-Item -Path $LogFilePath -ItemType File -Force
        "EPAC Hydration Kit Log File$('=' * 10)" | Set-Content -Path $LogFilePath
        "$timeStamp -- Log File Created" | Set-Content -Path $LogFilePath
    }
    switch ($EntryType) {
        "newStage" {
            $outputString = "Stage Initiated: $EntryData"
        }
        "commandStart" {
            $outputString = "Command Run: $EntryData"
            # Command output is not part of this because try/catch blocks are used to handle errors, and success has a number of different possible outcomes that include options in this list.
        }
        "testStart" {
            $outputString = "Beginning Test $EntryData"
        }
        "testResult" {
            $outputString = "Test Result Data: $EntryData"
        }
        "answerRequested" {
            $outputString = "Requesting response to: $EntryData"
        }
        "answerSetProvided" {
            $outputString = "Response(s) Provided: $EntryData"
        }
        "logEntryDataAsPresented" {
            $outputString = "$EntryData"
        }
    }
    if (!($Silent)) {
        if ($ForegroundColor) {
            Write-Host $outputString -ForegroundColor $ForegroundColor
        }
        else {
            Write-Host $outputString
        }
    }
    "$timeStamp -- $outputString" | Out-File -FilePath $LogFilePath -Encoding ascii -Append -Force
}