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
    $textRow = -join (($SmallRowCharacter * ([math]::Floor(($TerminalWidth - $modifiedDisplayText.Length) / 2))), $modifiedDisplayText, ($SmallRowCharacter * ([math]::Ceiling(($TerminalWidth - $modifiedDisplayText.Length) / 2))))
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
