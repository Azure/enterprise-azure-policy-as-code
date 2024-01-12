[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [string]
    $DisplayName
)

. "$PSScriptRoot/../Helpers/Get-ScrubbedString.ps1"

$invalidChars = [IO.Path]::GetInvalidFileNameChars()
$invalidChars += (":[]()$".ToCharArray())

$scrubbed = Get-ScrubbedString -String $DisplayName -InvalidChars $invalidChars -ReplaceWith "-" -ReplaceSpaces -ReplaceSpacesWith "-" -MaxLength 100 -TrimEnds -ToLower -SingleReplace

Write-Output "referenceID = `"$scrubbed`""
Write-Output "effectParam = `"effect-$scrubbed`""