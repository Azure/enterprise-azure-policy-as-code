function New-HydrationAnswerSet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $LoopId,
        [Parameter(Mandatory = $true)]
        [string]
        $QuestionsFilePath,
        [Parameter(Mandatory = $true)]
        [string]
        $LogFilePath,
        [Parameter(Mandatory = $false)]
        [array]
        $Notes, # This allows dynamic data to be passed for display in the loop to guide the user in their responses.
        [Parameter(Mandatory = $false)]
        [Int32]
        $TerminalWidth = 80,
        [Parameter(Mandatory = $false)]
        [switch]
        $UseUtc
    )
    if (!(Test-Path $QuestionsFilePath)) {
        Write-Error "Questions file not found at $QuestionsFilePath"
        return "Failed, Questions file not found at $QuestionsFilePath...."
    }
    else {
        $fullQuestionsList = Get-Content $QuestionsFilePath | ConvertFrom-Json -Depth 10 -AsHashtable
        $questionsList = @{}
        foreach ($questionKey in $fullQuestionsList.Keys) {
            if ($fullQuestionsList.$questionKey.loopId -eq $LoopId) {
                $questionsList.Add($questionKey, $fullQuestionsList.$questionKey)
            }
        }
    }
    $responseList = [ordered]@{}
    foreach ($question1 in $questionsList.Keys) {
        $responseList.Add($questionsList.$question1.outputVariableName, "Skipped")
    }
    $responseIncrement = 1
    $responseMax = $responseList.Keys.Count
    foreach ($questionIncrement in $responseIncrement..$responseMax) {
        # Outer loop to set order of questions
        foreach ($question in $questionsList.Keys) {
            # Clear-Host
            if ($questionIncrement -eq $questionsList.$question.questionIncrement) {
                $questionData = $questionsList.$question
                $blockData = @{
                    DisplayText           = $questionData.displayText
                    Location              = "Middle"
                    TextRowCharacterColor = "Blue"
                    RowCharacterColor     = "Yellow"
                    LargeRowCharacter     = "-"
                    SmallRowCharacter     = "-"
                    TerminalWidth         = $TerminalWidth
                }
                # Display the question as a UI
                New-HydrationSeparatorBlock @BlockData
                Write-Host "$($questionData.bodyHeader)`n" -ForegroundColor Yellow
                Write-Host "    $($questionData.bodyText)"
                if ($Notes) {
                    Write-Host "Notes:" -ForegroundColor Yellow
                    foreach ($note in $Notes) {
                        Write-Host "    - $note" -ForegroundColor Yellow
                    }
                }
                if ($questionData.links) {
                    Write-Host "`nLinks:" -ForegroundColor Yellow
                    foreach ($link in $questionData.links) {
                        Write-Host "    - $link"
                    }
                    if (!($questionData.inputType -eq "optionList")) {
                        # Evens out the presentation formatting for the blank line left in the optionList section due to format of .Net output
                        Write-Host "`n"
                    }
                }
                # Get the response
                do {
                    if ($questionData.inputType -eq "optionList") {
                        $questionResponse = New-HydrationMenuResponse -OptionHashtable $questionData.menuOptions -DataRequest $questionData.dataRequest
                    }
                    else {
                        $questionResponse = Read-Host $questionData.dataRequest 
                    }
                }until(($questionResponse -or $questionData.allowNull) -or $responseIncrement -eq 5)

                if ($questionResponse) {
                    $responseList.$($questionData.outputVariableName) = $questionResponse
                }
                elseif ($questionData.allowNull) {
                    $responseList.$($questionData.outputVariableName) = ""
                }
                else {
                    Write-Error "Responses are required for all questions. Exiting script."
                    return "Failed, please respond to all questions...."    
                }
                $responseIncrement++
            }
        }
    }
            
    return $responseList
}

# $lid = "optionalCreatePrimaryIntermediateRoot"
# $qfp = ".\StarterKit\HydrationKit\questions.jsonc"
# $lfp = ".\Output\Logs\Install-HydrationEpac.log"
# $n = @("Temporary nonsense")
# New-HydrationAnswerSet -LoopId $lid -QuestionsFilePath $qfp -LogFilePath $lfp -Notes $n