function New-HydrationSeparatorBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DisplayText,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Top", "Bottom", "Middle")]
        [string]
        $Location,
        [Parameter(Mandatory = $false)]
        [string]
        $TextRowCharacterColor = "Yellow",
        [Parameter(Mandatory = $false)]
        [string]
        $RowCharacterColor = "Green",
        [Parameter(Mandatory = $false)]
        [ValidateSet("=", "-", "*", "#", "_", "^", "!", "~", "+")]
        [string]
        $LargeRowCharacter = "=",
        [ValidateSet("=", "-", "*", "#", "_", "^", "!", "~", "+")]
        [string]
        $SmallRowCharacter = "-",
        [Parameter(Mandatory = $false)]
        [int]
        $TerminalWidth = 80
    )
    $smallRow = ($SmallRowCharacter * $TerminalWidth)
    $largeRow = ($LargeRowCharacter * $TerminalWidth)
    $modifiedDisplayText = " $DisplayText "
    $front = ([math]::Floor(($TerminalWidth - $modifiedDisplayText.Length) / 2))
    $back = ([math]::Ceiling(($TerminalWidth - $modifiedDisplayText.Length) / 2))
    if ($front -lt 0) { $front = 0 }
    if ($back -lt 0) { $back = 0 } 
    $textRow = -join (($SmallRowCharacter * $front), $modifiedDisplayText, ($SmallRowCharacter * $back))
    switch ($Location) {
        "Top" {
            Write-Host "`n`n$largeRow" -ForegroundColor $RowCharacterColor
            Write-Host "$textRow`n" -ForegroundColor $TextRowCharacterColor

        }
        "Middle" {            
            Write-Host "`n$smallRow" -ForegroundColor $RowCharacterColor
            Write-Host "$textRow" -ForegroundColor $TextRowCharacterColor
            Write-Host "$smallRow`n" -ForegroundColor $RowCharacterColor
        }
        "Bottom" {
            Write-Host "`n$textRow" -ForegroundColor $TextRowCharacterColor
            Write-Host "$largeRow`n`n" -ForegroundColor $RowCharacterColor
        }
    }
}
