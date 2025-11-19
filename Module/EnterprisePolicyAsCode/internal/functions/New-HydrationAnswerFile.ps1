<#
.SYNOPSIS
    This function creates a new Hydration Answer File.
.DESCRIPTION
    The New-HydrationAnswerFile function creates a new Hydration Answer File with values determined by an interactive session.
.EXAMPLE
    New-HydrationAnswerFile -Output "./CustomOutput"
    This example creates a new Hydration Answer File in the "./CustomOutput" directory.
.NOTES
    The Hydration Answer File is used to store answers for the hydration process.
.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function New-HydrationAnswerFile {
    [CmdletBinding()]
    param (
        # [Parameter(Mandatory = $false, HelpMessage = "The path to the StarterKit directory. Defaults to './StarterKit'.")]
        # [string]
        # $StarterKit = "./StarterKit",

        # [Parameter(Mandatory = $false, HelpMessage = "The path where the Hydration Answer File will be created. Defaults to './Output'.")]
        # [string]
        # $Output = "./Output",

        # [Parameter(Mandatory = $false, HelpMessage = "Switch to use UTC time.")]
        # [switch]
        # $UseUtc = $false
    )

    ################################################################################
    # Build Answer Response Container Object
    $returnData = [ordered]@{
        useCurrent               = "" # REMOVE
        useEpacBaseline          = ""
        usePciBaseline           = ""
        outputPath               = ""
        epacPrefix               = ""
        epacSuffix               = ""
        platform                 = ""
        pipelineType             = ""
        pipelinePath             = ""
        branchingFlow            = ""
        scriptType               = ""
        epacParentGroupName      = ""
        epacSourceGroupName      = ""
        pacOwnerId               = ""
        initialTenantId          = ""
        managedIdentityLocations = ""
        useCaf                   = ""
        environments             = [ordered]@{}
    }
    ################################################################################
    # Build supporting variables
    # $outputDirectory = Join-Path $Output "HydrationKit" 
    # $logFilePath = Join-Path $outputDirectory "HydrationKit.log"
    # $outputAnswerFilePath = Join-Path $outputDirectory "AnswerFile.json"
    # $inputDirectory = Join-Path $StarterKit "HydrationKit"
    # $answerFileInputPath = Join-Path $inputDirectory "questions.jsonc"
    # $testFileInputPath = Join-Path $inputDirectory "tests.jsonc"

    # cls
    # $stage = "Create the Answer File"
    # New-HydrationSeparatorBlock -DisplayText $stage -Location Top
    # Write-HydrationLogFile -EntryType "newStage" -LogFilePath $logFilePath -EntryData $stage
    # Write-Host "TODO: Complete this welcome page...." 
    # Write-Host "This hydration kit will..."
    # New-HydrationSeparatorBlock -DisplayText "Press any key to continue..." -Location Bottom
    # $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    ################################################################################
    # Process main questionnairre
    #   - Process each key in the json file as a page in the UI
    $loopQuestionCount = 10
    # TODO: Automate the above count by doing a filtered count of the inputObject on LoopId
    $questionIncrement = 1
    $loopId = "main"
    do {

        foreach ($questionKey in $answerFileInput.Keys) {
            if ($answerFileInput.$questionKey.loopId -eq "m" -and $answerFileInput.$questionKey.questionIncrement -eq $questionIncrement) {
                try {
                    $returnData.($answerFileInput.$questionKey.variablePath) = New-HydrationAnswer -InputObject $answerFileInput.$questionKey
                }
                catch {
                    Write-Error $Error[0]
                }
            }
        
            New-HydrationSeparatorBlock -DisplayText "Answer accepted, continuing..." -Location Bottom
            $questionIncrement++
            # Start-Sleep -Seconds 4
            # cls
        }
    }until($questionIncrement -eq $loopQuestionCount)
    Remove-Variable loopQuestionCount
    Remove-Variable questionIncrement
    Remove-Variable loopId
    ################################################################################
    # Process alz questionnairre (optional: undertaken if chosen as part of desired state during main questionnairre)
    $loopQuestionCount = 5
    # TODO: Automate the above count by doing a filtered count of the inputObject on LoopId
    $questionIncrement = 1
    $loopId = "alz"
    do {
        foreach ($questionKey in $answerFileInput.Keys) {
            if ($answerFileInput.$questionKey.loopId -eq "m" -and $answerFileInput.$questionKey.questionIncrement -eq $questionIncrement) {
                try {
                    $returnData.($answerFileInput.$questionKey.variablePath) = New-HydrationAnswer -InputObject $answerFileInput.$questionKey
                }
                catch {
                    Write-Error $Error[0]
                }
            }
        
            New-HydrationSeparatorBlock -DisplayText "Answer accepted, continuing..." -Location Bottom
            $questionIncrement++
            # Start-Sleep -Seconds 4
            # cls
        }
    }until($questionIncrement -eq $loopQuestionCount)
    Remove-Variable loopQuestionCount
    Remove-Variable questionIncrement
    Remove-Variable loopId
}