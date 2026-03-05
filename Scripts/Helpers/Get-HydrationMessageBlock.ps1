function Get-HydrationMessageBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $TerminalWidth
    )
$messageJson = @"
[
    {
        "displayPreliminaryTests": {
            "TerminalWidth": $TerminalWidth,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Blue",
            "SmallRowCharacter": "-",
            "DisplayText": "Summarizing Test Results",
            "LargeRowCharacter": "-",
            "Location": "Middle"
        },
        "gatherData": {
            "TerminalWidth": $TerminalWidth,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Blue",
            "SmallRowCharacter": "-",
            "DisplayText": "Beginning Data Gathering",
            "LargeRowCharacter": "-",
            "Location": "Middle"
        },
        "uiStart": {
            "TerminalWidth": $TerminalWidth,
            "RowCharacterColor": "Blue",
            "TextRowCharacterColor": "Cyan",
            "SmallRowCharacter": "+",
            "DisplayText": "Enterprise Policy as Code (EPAC) Hydration Kit",
            "LargeRowCharacter": "=",
            "Location": "Top"
        },
        "runPreliminaryTests": {
            "TerminalWidth": $TerminalWidth,
            "RowCharacterColor": "Blue",
            "TextRowCharacterColor": "Yellow",
            "SmallRowCharacter": "-",
            "DisplayText": "Beginning Preliminary Tests",
            "LargeRowCharacter": "+",
            "Location": "Top"
        },
        "generateAnswerFile": {
            "TerminalWidth": null,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Blue",
            "SmallRowCharacter": "+",
            "DisplayText": "Beginning Interview Process to Define EPAC Deployment",
            "LargeRowCharacter": "-",
            "Location": "Top"
        },
        "displayAnswerData": {
            "TerminalWidth": null,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Blue",
            "SmallRowCharacter": "-",
            "DisplayText": "Summarizing Answers Provided/Generated",
            "LargeRowCharacter": "-",
            "Location": "Middle"
        },
        "writeAnswerFile": {
            "TerminalWidth": null,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Green",
            "SmallRowCharacter": "+",
            "DisplayText": "Updating Answer File",
            "LargeRowCharacter": "-",
            "Location": "Middle"
        },
        "importAnswerFile": {
            "TerminalWidth": null,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Green",
            "SmallRowCharacter": "+",
            "DisplayText": "Importing Answer File",
            "LargeRowCharacter": "-",
            "Location": "Middle"
        },
        "beginHydrationProcess": {
            "TerminalWidth": null,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Blue",
            "SmallRowCharacter": "-",
            "DisplayText": "Beginning Hydration Process",
            "LargeRowCharacter": "-",
            "Location": "Top"
        },
        "populateRepoDefinitions": {
            "TerminalWidth": null,
            "RowCharacterColor": "Yellow",
            "TextRowCharacterColor": "Green",
            "SmallRowCharacter": "+",
            "DisplayText": "Using Answer Data to Generate Definitions Folder Contents",
            "LargeRowCharacter": "-",
            "Location": "Middle"
        }
    }
]
"@
$json = $messageJson | ConvertFrom-Json -depth 4 -AsHashtable
return $json
}