<#
.SYNOPSIS
    This function deploys Enterprise Policy as Code locally, and configures the repo to be uploaded to the platform of your choice.
.DESCRIPTION
    The Install-HydrationEpac function deploys the Enterprise Policy as Code. It takes several optional parameters: DefinitionsRootFolder, StarterKit, AnswerFile, Output, StopPoint, UseUtc, Interactive, and SkipTests. 
.PARAMETER TenantIntermediateRoot
    The path to the Tenant Intermediate Root. This parameter is mandatory.
.PARAMETER DefinitionsRootFolder
    The path to the Definitions directory. Defaults to "./Definitions".
.PARAMETER StarterKit
    The path to the StarterKit directory. Defaults to "./StarterKit".
.PARAMETER Output
    The path to the Output directory. Defaults to "./Output".
.PARAMETER AnswerFile
    The path to the Answer file. This parameter is optional and does not have a default value.
.PARAMETER UseUtc
    Switch to use UTC time.
.PARAMETER Interactive
    Switch to enable interactive mode.
.PARAMETER SkipTests
    Switch to skip preliminary tests.
.EXAMPLE
    Install-HydrationEpac -TenantIntermediateRoot "/path/to/root"
    This example deploys the Enterprise Policy as Code using the specified Tenant Intermediate Root and default directories, which is appropriate if being run from the root of the new repo.
.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function Install-HydrationEpac {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The path to the Tenant Intermediate Root. This parameter is mandatory.")]
        [string]
        $TenantIntermediateRoot,
        [Parameter(Mandatory = $false, HelpMessage = "The path to the Definitions directory. Defaults to './Definitions'.")]
        [string]
        $DefinitionsRootFolder = "./Definitions",
        [Parameter(Mandatory = $false, HelpMessage = "The path to the StarterKit directory. Defaults to './StarterKit'.")]
        [string]
        $StarterKit = "./StarterKit",
        [Parameter(Mandatory = $false, HelpMessage = "The path to the Output directory. Defaults to './Output'.")]
        [string]
        $Output = "./Output",
        [Parameter(Mandatory = $false, HelpMessage = "The path to the Answer file. This parameter is optional and does not have a default value.")]
        [string]
        $AnswerFile,
        [Parameter(Mandatory = $false, HelpMessage = "Switch to use UTC time.")]
        [switch]
        $UseUtc,
        [Parameter(Mandatory = $false, HelpMessage = "Switch to enable interactive mode.")]
        [switch]
        $Interactive,
        [Parameter(Mandatory = $false, HelpMessage = "Switch to skip preliminary tests.")]
        [switch]
        $SkipTests

    )
    Clear-Host
    $sleepTime = 10
    # Define Verbosity
    $InformationPreference = "Continue"
    if ($DebugPreference -eq "Continue") {
        $debug = $true
    }
    else {
        $Silent = $true
    }

    # Move to repo root as EPAC generally prefers to be run from this location
    $repoRootPath = Split-Path $DefinitionsRootFolder
    Set-Location $repoRootPath
    $logDirectory = Join-Path $Output "Logs"
    $logFilePath = Join-Path $logDirectory "Install-HydrationEpac.log"
    $questionsFilePath = Join-Path $StarterKit "HydrationKit" "questions.jsonc"
    $pathsToTest = @($DefinitionsRootFolder, `
        $logDirectory, `
        $Output)
    # Import, fail to import, or create the answer file
    if ($AnswerFile) {
        $answerFilePath = $AnswerFile
        if (!(Test-Path $AnswerFile)) {
            Write-Error "Answer file not found at $AnswerFile, exiting..."
            return
        }
        $allInterviewAnswers = Get-Content $AnswerFile `
            | ConvertFrom-Json -Depth 10 -AsHashtable
    }
    else {
        $answerFilePath = Join-Path $Output `
            "HydrationAnswer" `
            "AnswerFile.json"
        if (!(Test-Path $(Split-Path $AnswerFilePath))) {
            $null = New-Item -Path $(Split-Path $AnswerFilePath) -ItemType Directory -Force
        }
        else {
            Write-Warning "A file already exists at $AnswerFilePath, and will be overwritten unless you use Ctrl+C to exit..."
            Read-Host "Press Enter to continue..."
            Write-HydrationLogFile -EntryType logEntryDataAsPresented `
                -EntryData "Overwriting Answer File at $AnswerFilePath" `
                -LogFilePath $logFilePath `
                -UseUtc:$UseUtc `
                -Silent
        }
        "" | Set-Content $AnswerFilePath -Force
    }
    $pathsToTest += $answerFilePath

    # Define UI Width for display automation
    if ($host.UI.RawUI.WindowSize.Width -lt 80 -or $host.UI.RawUI.WindowSize.Width -eq "" -or $null -eq $host.UI.RawUI.WindowSize.Width) {
        $TerminalWidth = 80
    }
    else {
        $TerminalWidth = $host.UI.RawUI.WindowSize.Width
    }
    # Crete an ordered hashtable to hold log entries until the directories are tested
    $endSummary = [PSCustomObject]@{
        preliminaryTestResults  = [ordered]@{}
        gatherData              = [ordered]@{}
        generateAnswerFile      = [ordered]@{}
        importAnswerFile        = [ordered]@{}
        populateRepoDefinitions = [ordered]@{}
        createRepo              = [ordered]@{}
        testRepo                = [ordered]@{}
        testAndPlan             = [ordered]@{}
        buildRepo               = [ordered]@{}
        deployRepo              = [ordered]@{}
        deployPipelines         = [ordered]@{}
        deployPolicyAssignments = [ordered]@{}
        deployPolicyDefinitions = [ordered]@{}
        deployPolicyRoles       = [ordered]@{}
    }
    $interviewQuestionSets = [ordered]@{
        initial                               = $true
        optionalCreatePrimaryIntermediateRoot = $false
        optionalCreateMainCaf3Hierarchy       = $false
        tenantList                            = $false # Future state
        pacSelector                           = $true
        updatesByPacSelector                  = $true
        policyDecisionsByPacSelector          = $true
        pipeline                              = $true
    }
    $roleMessages = @{
        "PassedEpacAllDeploy"    = "- The script will be unable to assist with building the new management groups for EPAC to test with during development. However, RBAC Authorization tests passed, and you have the necessary permissions to deploy the EPAC solution to existing management groups. It is recommended that you ensure that you already have your epac development hierarchy in place prior to continuing so that these initial test deployments can be run."
        "PassedEpacPolicyDeploy" = "- The script will be unable to deploy any roles to support policies that are deployed by EPAC. This can result in an unsupported state, so no deployments step will be offered."
        "PassedEpacRoleDeploy"   = "- The script will be unable to deploy any policies used by the roles that will be deployed by EPAC. This can result in an unsupported state, so no deployment step will be offered."
        "PassedEpacPlan"         = "- The script will be unable to deploy any aspect of the EPAC solution to Azure. Only a plan step will be offered."
        "Failed"                 = "- The script will be unable to plan a deployment to support the EPAC solution. No plan step will be offered, and there will be no attempt to gather data from Azure programatically to simplify this process."
    }
    $limitation = [ordered]@{
        Write  = @{
            Status              = $false
            Message             = "The script will be unable to create the epac testing environment for testing as part of this process. Consider manually creating these management groups prior to continuing..." 
            optionalCaf3Message = "This script will be unable to create the requisite management groups for the new caf3 management group hierarchy due to limitations of the account used for the current connection to Azure, these questions will be skipped. Consider creating the new Tenant Intermediate Root Group and restarting the process"
            optionalTirMessage  = "This script will be unable to create the recommended management groups for the new caf3 management group hierarchy due to limitations of the account used for the current connection to Azure, these questions will be skipped. STRONGLY consider creating the new Tenant Intermediate Root Group and restarting the process."
        }
        Policy = @{
            Status  = $false
            Message = "The script will be unable to deploy policy, and will not continue beyond the plan phase." 
        }
        Role   = @{
            Status  = $false
            Message = "The script will be unable to deploy roles that are needed to support policy deployment, and will not continue beyond the plan phase." 
        }
        Plan   = @{
            Status  = $false
            Message = "The script is unable to read the environment to generate a plan, so deployment of Azure Policy will not be tested against the EPAC development environment specified."
        }
        Gather = @{
            Status  = $false
            Message = "The script will be unable to gather data from Azure programatically to simplify this process. No insights from Azure can be gained to assist in guiding you through this process... Stopping now and rerunning the tests after connecting to Azure with an account that has more comprehensive rights, at least Read, to Azure, is STRONGLY recommended." 
        }
        Git    = @{
            Status  = $false
            Message = "The script will be unable to programatically download the StarterKit from GitHub. Please ensure that you have an updated copy of StarterKit in the same directory as the Definitions folder, based on the choices made in this script." 
        }
    }
    $stageBlocks = Get-Content $(Join-Path $StarterKit 'HydrationKit' 'blockDefinitions.jsonc') | ConvertFrom-Json -Depth 5 -AsHashtable
    foreach($key in $stageBlocks.keys) {
        $stageBlocks.$key.TerminalWidth = $TerminalWidth
    }

    Clear-Host
    ################################################################################
    ################################################################################
    # Initiate UI: Header 
    $summary = [ordered]@{}
    $uiStart = $stageBlocks.uiStart
    New-HydrationSeparatorBlock @uiStart
    Write-HydrationLogFile -EntryType newStage `
        -EntryData $stageBlocks.uiStart.DisplayText `
        -LogFilePath $logFilePath `
        -UseUtc:$UseUtc `
        -Silent

    # Initiate UI: Body
    Write-Warning "This script is currently in Beta release. Please report any issues to the EPAC team."
    # TODO Add a welcome message here that is more informative than the current placeholder.
    Write-Host "Welcome to the Enterprise Policy as Code (EPAC) Hydration Kit. This script is intended to help guide you through the EPAC Deployment process." -ForegroundColor Yellow
    # Initiate UI: Footer
    New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime
    Clear-Host

    ################################################################################
    ################################################################################
    # Preliminary Tests: Path Header
    $summary = [ordered]@{}
    $runPreliminaryTests = $stageBlocks.runPreliminaryTests
    New-HydrationSeparatorBlock @runPreliminaryTests
    Write-HydrationLogFile -EntryType newStage `
        -EntryData $stageBlocks.runPreliminaryTests.DisplayText `
        -LogFilePath $logFilePath `
        -UseUtc:$UseUtc `
        -Silent
    ################################################################################
    # Preliminary Tests: Path Body
    Write-Host "Beginning path tests to help ensure that the script can run successfully..." -ForegroundColor Yellow
    # Test for and create directories if they do not exist, this allows realtime logging to file to begin

    if ($SkipTests){
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Skipping tests..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Magenta
    }else {
        foreach ($path in $pathsToTest) {
            $pathTest = Test-HydrationPath -LocalPath $path `
                -UseUtc:$UseUtc `
                -LogFilePath $logFilePath `
                -Silent
            if ($pathTest -eq "Failed") {
                Write-Error "The path $path could not be created. Please choose a location to work in that you have write access to and restart the process."
                $summary.Add($path, "Failed")
            }
            else {
                $summary.Add($path, "Passed")
            }
        }
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Summary of $($stageblocks.runPreliminaryTests.DisplayText)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        foreach ($entry in $summary.keys) {
            Write-HydrationLogFile -EntryType testResult -EntryData "$entry -- $($summary.$entry)" -UseUtc:$UseUtc -LogFilePath $logFilePath -Silent
            Start-Sleep -Seconds $sleepTime
        }
        
        # Begin Azure Network Connection Tests
        Write-Host "Beginning connectivity tests to help ensure that the script can run successfully..." -ForegroundColor Yellow
        $connectionTestUrlList = [ordered]@{
            internetConnection  = "13.107.42.14" # Used in Microsoft Automated Testing (per CoPilot)
            githubConnection    = "www.github.com"
            azureManagement     = (Get-AzContext).Environment.ResourceManagerUrl | Select-String -Pattern "https?://([^/]+)/?" | ForEach-Object {
                $_.Matches[0].Groups[1].Value
            }
            azureAuthentication = (Get-AzContext).Environment.ActiveDirectoryAuthority | Select-String -Pattern "https?://([^/]+)/?" | ForEach-Object {
                $_.Matches[0].Groups[1].Value
            }
        }
        foreach ($url in $connectionTestUrlList.Keys) {
            $connectionTest = Test-HydrationConnection -FullyQualifiedDomainName $connectionTestUrlList.$url -UseUtc:$UseUtc -LogFilePath $logFilePath -Silent
            if ($connectionTest -eq "Failed") {
                # Write-Error "The test for $url failed when tested with the value $($connectionTestUrlList.$url). Please ensure that you have an active internet connection and that the Azure services are available. This will not prevent continuing with the process, but it will prevent use of much of the accelerator, as well as gathering of data to provide guidance in this process, and is not recommended."
                $summary.Add($url, "Failed")
            }
            else {
                $summary.Add($url, "Passed")
            }
            Write-HydrationLogFile -EntryType testResult -EntryData "$url -- $($summary.$url)" -UseUtc:$UseUtc -LogFilePath $logFilePath -Silent
        }
        
        # Begin Azure Authorization Tests
        Write-Host "Beginning RBAC Authorization tests to help ensure that the script can run successfully..." -ForegroundColor Yellow
        Write-Host "- This will only check for direct assignments, and will not take into account group membership, as it requires API calls to Entra ID that are not within the scope of EPAC's mission." -ForegroundColor Yellow
        Write-Host "    - Creation, and Removal, of a Management group at Tenant Root will effectively confirm privileges if the test must be bypassed/ignored for this reason." -ForegroundColor Yellow
        Write-Host "- If your terminal appears to hang during this process, it is likely that the script is waiting for an authentication prompt in the medium configured for your terminal session. This is generally the default web browser. Please check for hidden windows." -ForegroundColor Magenta
        Write-Host "    - For example, VSCode's default Terminal behavior is to open a login window in the default web browser IN THE BACKGROUND, a pop-under. Please check for this window if you are using VSCode." -ForegroundColor Magenta
        $rbacTest = Test-HydrationRbacAssignment -Scope $(Get-AzContext).Tenant.Id -Output:$Output -UseUtc:$UseUtc -LogFilePath $logFilePath -Silent
        $summary.add("RbacAuthorization", $rbacTest)
        Write-Host "Beginning git tests to help ensure that the script can run successfully..." -ForegroundColor Yellow
        try {
            if (($(git --help))) {
                $summary.add("gitInstall", "Passed")
            }
        }
        catch {
            $summary.add("gitInstall", "Failed")
        }
        
        Write-Host "Reviewing Returns..." -ForegroundColor Yellow
        
        # Process failed tests for warning messages and script limitations calculations
        $failedTests = @{}
        foreach ($key in $summary.keys) {
            if ($summary.$key -like "Failed*") {
                $failedTests.Add($key, $summary.$key)
            }
        }
        
        if ($failedTests.keys.count -gt 0 -or (!($($summary.RBACAuthorization -eq "PassedHydrationDeploy")))) {
            Write-Host "The following items should be considered before continuing:" -ForegroundColor Red
            foreach ($key in $failedTests.keys) {
                switch ($key) {
                    "githubConnection" {
                        Write-Host "    - The test for a connection to GitHub failed. You will need to ensure that the StarterKit folder has been downloaded to the same directory that your Definitions folder is now in, based on the choices made in this script.`
                        `n        - This is not a blocker if you have a fresh copy of the StarterKit in the same directory as the Definitions folder, and you already have access to the module. However, this script requires the presence of that folder in the repo to continue, either through automated or manual means.`
                        `n        - Download Location: https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit" -ForegroundColor Yellow
                    }
                    "azureManagement" {
                        Write-Host "     - The test for the management connection to Azure failed. The script will be unable to plan a deployment to support the EPAC solution. No plan step will be offered, and there will be no attempt to gather data from Azure programatically to simplify this process." -ForegroundColor Red
                        $limitation.azureManagement.Status = $true
                    }
                    "azureAuthentication" {
                        Write-Host "     - The test for the authentication connection to Azure failed. The script will be unable to plan a deployment to support the EPAC solution. No plan step will be offered, and there will be no attempt to gather data from Azure programatically to simplify this process."  -ForegroundColor Red
                        $limitation.azureAuthentication.Status = $true
                    }
                    "gitInstall" {
                        Write-Host "    - The test for git software has failed. You will need to ensure that the StarterKit folder has been manually downloaded to the same directory that your Definitions folder is now in, based on the choices made in this script.`
                        `n        - This is not a blocker if you have a fresh copy of the StarterKit in the same directory as the Definitions folder, and you already have access to the module. However, this script requires the presence of that folder in the repo to continue, either through automated or manual means.`
                        `n        - Download Location: https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit" -ForegroundColor Yellow
                        $limitation.git.Status = $true
                    }
                }
            }
            switch ($summary.RbacAuthorization) {
                "PassedEpacAllDeploy" {
                    Write-Host "    $($roleMessages.PassedEpacAllDeploy)" -ForegroundColor Red
                }
                "PassedEpacPolicyDeploy" {
                    Write-Host "    $($roleMessages.PassedEpacAllDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacPolicyDeploy)" -ForegroundColor Red
                    $limitation.Write.Status = $true
                    $limitation.Role.Status.Status = $true
                }
                "PassedEpacRoleDeploy" {
                    Write-Host "    $($roleMessages.PassedEpacRoleDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacAllDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacPolicyDeploy)" -ForegroundColor Red
                    $limitation.Write.Status = $true
                    $limitation.Policy.Status = $true
                }
                "PassedEpacPlan" {
                    Write-Host "    $($roleMessages.PassedEpacPlan)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacRoleDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacAllDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacPolicyDeploy)" -ForegroundColor Red
                    $limitation.Write.Status = $true
                    $limitation.Policy.Status = $true
                    $limitation.Role.Status = $true
                }
                "Failed" {
                    Write-Host "    $($roleMessages.PassedEpacAllDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacPlan)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacRoleDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacAllDeploy)" -ForegroundColor Red
                    Write-Host "    $($roleMessages.PassedEpacPolicyDeploy)" -ForegroundColor Red
                    $limitation.Write.Status = $true
                    $limitation.Plan = $true
                    $limitation.Policy.Status = $true
                    $limitation.Role.Status = $true
                    $limitation.Gather = $true
                }
            }
        }
        else {
            Write-Host "All tests indicate that the connection is in an optimal state for the EPAC installation process. Additional data will be gathered using these connections, and errors after this point will generally indicate a unique condition such as an inheritance block/override for RBAC authority." -ForegroundColor Green
        }
        



        ################################################################################
        # Preliminary Tests: Footer

        # Summary separator block
        $displayPreliminaryTests = $stageBlocks.displayPreliminaryTests
        New-HydrationSeparatorBlock @displayPreliminaryTests
        Write-HydrationLogFile -EntryType newStage -EntryData $stageBlocks.displayPreliminaryTests.DisplayText -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent

        # Display Summary
        $testSummarySeparator = "-"
        foreach ($hashkey in $summary.keys) {
            $hashString = $( -join ($hashKey, " ", ($testSummarySeparator * ($TerminalWidth - ($hashKey.Length + $($summary.$hashKey).Length + 2))), " ", $($summary.$hashKey)))
            if ($summary.$hashkey -like "Failed*") {
                Write-Host $hashString -ForegroundColor Red
            }
            else {
                Write-Host $hashString -ForegroundColor Green
            }
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Summary: $hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        }
        Write-Host "`n`n"

        # Pause for review based on interactive message from input
        New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime
    }
    ################################################################################
    ################################################################################
    # Begin Data Gather Process to Support EPAC Deployment
    $summary = [ordered]@{}
    $gatherData = $stageBlocks.gatherData
    New-HydrationSeparatorBlock @gatherData
    Write-HydrationLogFile -EntryType newStage -EntryData $stageBlocks.displayPreliminaryTests.DisplayText -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
    if ($limitation.Gather.Status) {
        Write-HydrationLogFile -EntryType answerRequested -EntryData $limitation.Gather.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent    
        Write-Host limitation.Gather.Message -ForegroundColor Red
        $continueWithoutRead = New-HydrationAnswer `
            -QuestionData "Would you like to continue without the ability to gather data from Azure?" `
            -AnswerOptions "Yes", "No" `
            -DefaultValue "No"
        if ($continueWithoutRead -eq "Yes") {
            Write-Host "Continuing without the ability to gather data from Azure..." -ForegroundColor DarkRed
        }
        else {
            Write-Host "Stopping the process to allow for a connection to Azure with an account that has more comprehensive rights, at least Read, to Azure." -ForegroundColor Red
            return
        }
    }
    else {
        Write-Host "Beginning data gathering process..." -ForegroundColor Yellow

        # Gather Data
        $gatherData = [ordered]@{}
        $environmentEntry = [ordered]@{
            pacSelector                = ""
            intermediateRootGroupName  = $TenantIntermediateRoot
            tenantId                   = $(Get-AzContext).Tenant.Id
            cloud                      = $(Get-AzContext).Environment.Name
            keepDfcSecurityAssignments = $false
            caf3Status                 = "Untested"
            intermediateRootStatus     = "Untested"
        }
        # Current Tenant Information
        try {
            $gatherData.Add('currentTenantPacSelector', $(Get-DeepCloneAsOrderedHashtable -InputObject $environmentEntry))
            $gatherData.currentTenantPacSelector.pacSelector = "tenant01" # Set Default for primary tenant, primary root (that will be cloned to epac-dev environment)
        }
        catch {
            Write-Error "Cannot find the EPAC helper command `'Get-DeepCloneAsOrderedHashtable`', please ensure that the EPAC module or is installed and available, or that the scripts directory is available and the helpers have been dot sourced for use."
            return
        }
        try {
            $gatherData.Add('locationList', @((Get-AzLocation).Location) -join ", ")
        }
        catch {
            Write-Error "Failed to gather Azure Location List, please ensure that you have a connection to Azure and try again."
            return
        }
        
        try {
            $tenantIntermediateRootTestResult = Get-AzManagementGroupRestMethod -GroupID $TenantIntermediateRoot
            # Identify if the property tested below is correct
        }
        catch {
            Write-Warning "Error returned retrieving the Tenant Intermediate Root. This generally means that it has not been created, and the interview process will continue with the assumption that it needs to be created."
        }
        if (!($tenantIntermediateRootTestResult.Id)) {
            $gatherData.currentTenantPacSelector.intermediateRootStatus = $environmentEntry.intermediateRootStatus = "Available"
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "The Tenant Intermediate Root Management Group does not exist, and will need to be created to be used." -LogFilePath $logFilePath -UseUtc:$UseUtc -silent 
            $interviewQuestionSets.optionalCreatePrimaryIntermediateRoot = $true
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Create Intermediate Root: `"$TenantIntermediateRoot`" does not exist, adding discussion items..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
         }
        else {
            $gatherData.currentTenantPacSelector.intermediateRootStatus = $environmentEntry.intermediateRootStatus = "Passed"
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "The TenantIntermediateRoot Management Group `"$TenantIntermediateRoot`"  is confirmed." -LogFilePath $logFilePath -UseUtc:$UseUtc -silent 
            $interviewQuestionSets.optionalCreatePrimaryIntermediateRoot = $false
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Create Intermediate Root Test: `"$TenantIntermediateRoot`" exists , no deployment is needed..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        try {
            $gatherData.currentTenantPacSelector.caf3Status = $environmentEntry.caf3Status = Test-HydrationCaf3Hierarchy -TenantId $(Get-AzContext).Tenant.Id -TenantIntermediateRoot $TenantIntermediateRoot -LogFilePath $logFilePath
        }
        catch {
            Write-Error $Error[0].Exception.Message
        }
        
        if ($tenantIntermediateRootTestResult.id) {
            $interviewQuestionSets.optionalCreatePrimaryIntermediateRoot = $false
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Create Intermediate Root Test: `"$TenantIntermediateRoot`" exists , no deployment is needed..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        else {
            $interviewQuestionSets.optionalCreatePrimaryIntermediateRoot = $true
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Create Intermediate Root: `"$TenantIntermediateRoot`" does not exist, adding discussion items..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        }
        $interviewQuestionSets.optionalCreatePrimaryIntermediateRoot = $true
        $interviewQuestionSets.optionalCreateMainCaf3Hierarchy = $true
        $interviewQuestionSets.optionalRequireCaf3HierarchyRename = $true
        # TODO: The logic below needs some work before it can be used effectively, need to think through when we still want to offer the option as this is too limiting.
        # switch ($gatherData.currentTenantPacSelector.caf3Status) {
        #     "PassedCaf3Exists" {
        #         $interviewQuestionSets.optionalCreatePrimaryIntermediateRoot = $false
        #         $interviewQuestionSets.optionalCreateMainCaf3Hierarchy = $true # May still want to create an alternate
        #         $interviewQuestionSets.optionalRequireCaf3HierarchyRename = $false # May still want to create an alternate
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Default CAF3 Hierarchy Test: CAF3 hierarchy is in place under the management group `"$TenantIntermediateRoot`" , no additional Management Group deployment items will be recommended." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        #     }
        #     "PassedRunCaf3" {
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Caf3 Hierarchy: CAF3 Hierarchy is a viable option under `"$TenantIntermediateRoot`", adding discussion items..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        #         $interviewQuestionSets.optionalCreateMainCaf3Hierarchy = $true
        #         $interviewQuestionSets.optionalRequireCaf3HierarchyRename = $false
        #     }
        #     "FailedNameCollision" {
        #         $interviewQuestionSets.optionalCreateMainCaf3Hierarchy = $true
        #         $interviewQuestionSets.optionalRequireCaf3HierarchyRename = $true
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Create CAF3 Hierarchy: A default CAF3 hierarchy does not exist in an expected state, which is to say that default names are used in a non-standard hierarchy. `
        #         `n    -This can be addressed by creating a new hierarchy (if desired) using a prefix/suffix to the standard default strings, adding discussion items..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        #     }
        #     "Failed" {
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Test Failed, please review error message, access levels, and connection to Azure before testing again." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
        #         $endAfterDataGather = $true
        #     }
        #     Default {
        #         $message = "This should not happen, `$gatherData.currentTenantPacSelector.caf3Status is set to an invalid value, '$($gatherData.currentTenantPacSelector.caf3Status)'"
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $message -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
        #         return
        #     }
        # }
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Data Gathered: $($gatherData | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        Write-Host "`n"
        $endSummary.gatherData = $summary
        New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime
    }
    if ($AnswerFile) {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Answer File Provided: $AnswerFilePath" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        try {
            $allInterviewAnswers = Get-Content $AnswerFilePath | ConvertFrom-Json -Depth 10 -AsHashtable
        }
        catch {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $Error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to import the answer file, please review the error message and rerun the process." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
        }
    }
    else {
        ################################################################################
        ################################################################################
        # Gather Deployment Decisions for/from Answer File

        # Run Interview Process
        Clear-Host
        $stageBlock = $stageBlocks.generateAnswerFile
        $allInterviewAnswers = [ordered]@{}
        New-HydrationSeparatorBlock @stageBlock
        Write-HydrationLogFile -EntryType newStage -EntryData $stageBlock.DisplayText  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
    
        ################################################################################
        # Main Tenant Loops
        ############
        # Confirm Tenant
        $loopId = "initial"
        Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        if ($interviewQuestionSets.$loopId) {
            $loopNotes = @(
                "Current Tenant ID: $((Get-AzContext).tenant.Id)"
            )
            try {
                $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -Notes $loopNotes -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
            }
            catch {
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
                return
            }
            Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Remove-Variable loopId -ErrorAction SilentlyContinue
            Remove-Variable loopNotes -ErrorAction SilentlyContinue
            Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
            foreach ($intKey in $interview.keys) {
                $allInterviewAnswers.Add($intKey, $interview.$intKey)
                $testSummarySeparator = "-"
                $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            }
            # Process Responses
            if ($interview.initialTenantId -eq "Yes") {
                $allInterviewAnswers.initialTenantId = (Get-AzContext).tenant.id
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "`nNo Tenant ID was provided, using the current Tenant ID...`n" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
            }
            else {
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "`nDiffering Tenant ID provided, exiting to use the provided Tenant ID...`n" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
                Write-Error "Reconnect to the appropriate Tenant ID using `'Connect-AzAccount -TenantId [YourTenantId]`', and then rerun the process."
                return
            }
            if ($interview.pacOwnerId -eq "" -or $null -eq $interview.pacOwnerId) {
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "`nNo Owner ID was provided, generating a new GUID for the Owner ID...`n" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
                $interview.pacOwnerId = $allInterviewAnswers.pacOwnerId = (New-Guid).Guid
                $testSummarySeparator = "-"
                $ikey = "PacOwnerId Generated"
                $hashString = $( -join ($ikey, " ", ($testSummarySeparator * ($TerminalWidth - ($ikey.Length + $($interview.pacOwnerId).Length + 2))), " ", $($interview.pacOwnerId)))
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            }
            New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime
            $allInterviewAnswers.initialTenantCloud = (Get-AzContext).environment.name
            $allInterviewAnswers.initialTenantIntermediateRoot = $TenantIntermediateRoot
        }

        $loopId = "optionalCreatePrimaryIntermediateRoot"
        Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        if ($environmentEntry.intermediateRootStatus -eq "Available" -and $interviewQuestionSets.$loopId) {
            $loopNotes = @(
                "$TenantIntermediateRoot Name Status: $($environmentEntry.intermediateRootStatus)"
            )
            try {
                $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -Notes $loopNotes -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
            }
            catch {
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
                return
            }
            Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Remove-Variable loopId -ErrorAction SilentlyContinue
            Remove-Variable loopNotes -ErrorAction SilentlyContinue
            Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
            foreach ($intKey in $interview.keys) {
                $allInterviewAnswers.Add($intKey, $interview.$intKey)
                $testSummarySeparator = "-"
                $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green

            }
            New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime
        }
        # ############
        # # Main Tenant Caf3 Loop
        $loopId = "optionalCreateMainCaf3Hierarchy"
        Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        if ($interviewQuestionSets.$loopId -and $allInterviewAnswers.createMainCaf3Hierarchy -eq "Yes") { 
            if ($environmentEntry.caf3Status -eq "FailedNameCollision") {
                $loopNotes = @( "CAF3 Hierarchy will require a prefix and/or suffix in order to be deployed properly.")
            }   
            try {
                $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -Notes $loopNotes -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
            }
            catch {
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
                return
            }
            Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
            foreach ($intKey in $interview.keys) {
                $allInterviewAnswers.Add($intKey, $interview.$intKey)
                $testSummarySeparator = "-"
                $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            }
            New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime    
            Remove-Variable loopId -ErrorAction SilentlyContinue
            Remove-Variable loopNotes -ErrorAction SilentlyContinue
        }
        elseif ($environmentEntry.intermediateRootStatus -eq "PassedCaf3Exists" ) {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "CAF3 Hierarchy is in place under the management group `"$TenantIntermediateRoot`", skipping Caf3 Deployment questions." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }

        ############
        # Main Tenant Caf3 Naming Loop
        # $loopId = "optionalCreateMainCaf3HierarchyNaming"
        # Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        # if ($allInterviewAnswers.createMainCaf3Hierarchy -eq "Yes") {
        #     if ($environmentEntry.caf3Status -eq "FailedNameCollision") {
        #         $loopNotes = @( "CAF3 Hierarchy will require a prefix and/or suffix in order to be deployed properly.")
        #     }   
        #     try {
        #         $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -Notes $loopNotes -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
        #     }
        #     catch {
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        #         Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
        #         return
        #     }
        #     Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        #     Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
        #     foreach ($intKey in $interview.keys) {
        #         $allInterviewAnswers.Add($intKey, $interview.$intKey)
        #         $testSummarySeparator = "-"
        #         $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
        #         Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green

        #     }
        #     New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime    
        #     Remove-Variable loopId -ErrorAction SilentlyContinue
        #     Remove-Variable loopNotes -ErrorAction SilentlyContinue
        # }
        # else {
        #     Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "CAF3 Hierarchy name mutation not requested." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        # }

        ############
        # corePacSelectors Loop
        $loopId = "corePacSelectors"
        Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        if ($summary.RbacAuthorization -like "Passed*") {
            $loopNotes = @("Location List: $($endSummary.gatherData.locationList)")
        }
        else{
            $loopNotes = @("Location List: Rbac Test Failed, no location list gathered.")
        }
        try {
            $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -Notes $loopNotes -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
        }
        catch {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
            return
        }
        Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
        foreach ($intKey in $interview.keys) {
            $allInterviewAnswers.Add($intKey, $interview.$intKey)
            $testSummarySeparator = "-"
            $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green

        }
        Remove-Variable loopId -ErrorAction SilentlyContinue
        Remove-Variable loopNotes -ErrorAction SilentlyContinue
        if ($interview.mainTenantMainPacSelectorName -eq "" -or $null -eq $interview.mainTenantMainPacSelectorName -or -not $interview.mainTenantMainPacSelectorName) {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "No pacSelectorName was provided, using 'tenant01'..." -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "`nNo pacSelectorName was provided, setting default value...`n" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
            $interview.mainTenantMainPacSelectorName = $allInterviewAnswers.mainTenantMainPacSelectorName = "tenant01"
            $testSummarySeparator = "-"
            $ikey = "pacSelectorName"
            $hashString = $( -join ($ikey, " ", ($testSummarySeparator * ($TerminalWidth - ($ikey.Length + $($interview.mainTenantMainPacSelectorName).Length + 2))), " ", $($interview.mainTenantMainPacSelectorName)))
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        if ($interview.epacParent -eq "" -or $null -eq $interview.epacParent -or -not $interview.epacParent) {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "No Parent for EPAC was provided, using Tenant Root for the Parent..." -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "`nNo epacParent was provided, setting default value...`n" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
            $interview.epacParent = $allInterviewAnswers.epacParent = $gatherData.currentTenantPacSelector.tenantId
            $testSummarySeparator = "-"
            $ikey = "epacParent"
            $hashString = $( -join ($ikey, " ", ($testSummarySeparator * ($TerminalWidth - ($ikey.Length + $($interview.epacParent).Length + 2))), " ", $($interview.epacParent)))
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime    

        ############
        # epacModifier Loop
        $loopId = "epacModifier"
        Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent

        try {
            $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
        }
        catch {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
            return
        }
        Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
        foreach ($intKey in $interview.keys) {
            $allInterviewAnswers.Add($intKey, $interview.$intKey)
            $testSummarySeparator = "-"
            $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        $epacDevRoot = $( -join ($interview.epacPrefix, $TenantIntermediateRoot, $interview.epacSuffix))
        if ($epacDevRoot -eq $TenantIntermediateRoot) {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "`nEPAC Development Root $epacDevRoot is equal to the specified Tenant Intermediate Root group, $TenantIntermediateRootGroup. This will result in a name collision. Please choose a prefix and/or suffx when you run this process again." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
            New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime
            return
        }
        else {
            $testSummarySeparator = "-"
            $ival = $( -join ($interview.epacPrefix, $TenantIntermediateRoot, $interview.epacSuffix))
            $ikey = 'EpacDevelopmentRoot'
            $hashString = $( -join ($ikey, " ", ($testSummarySeparator * ($TerminalWidth - ($ikey.Length + $ival.Length + 2))), " ", $ival))
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            $allInterviewAnswers.Add($ikey, $ival)
            # Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "`nEPAC Development Root: " -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        Remove-Variable ikey -ErrorAction SilentlyContinue
        Remove-Variable ival -ErrorAction SilentlyContinue
        Remove-Variable loopId -ErrorAction SilentlyContinue
        Remove-Variable loopNotes -ErrorAction SilentlyContinue
        New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime    

        ############
        # policyDecisions Loop
        $loopId = "policyDecisions"
        Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent

        try {
            $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
        }
        catch {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
            return
        }
        Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
        foreach ($intKey in $interview.keys) {
            $allInterviewAnswers.Add($intKey, $interview.$intKey)
            $testSummarySeparator = "-"
            $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        Remove-Variable loopId -ErrorAction SilentlyContinue
        Remove-Variable loopNotes -ErrorAction SilentlyContinue
        New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime    

        ############
        # pipelineDecisions Loop
        $loopId = "pipelineDecisions"
        Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent

        try {
            $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
        }
        catch {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
            return
        }
        Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
        Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
        foreach ($intKey in $interview.keys) {
            $allInterviewAnswers.Add($intKey, $interview.$intKey)
            $testSummarySeparator = "-"
            $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
        }
        Remove-Variable loopId -ErrorAction SilentlyContinue
        Remove-Variable loopNotes -ErrorAction SilentlyContinue
        New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime 

        ############
        # otherPipeline Loop

        if ($AllInterviewAnswers.pipelinePlatform -eq "Other") {
            $loopId = "otherPipeline"
            Write-HydrationLogFile -EntryType newStage -EntryData "Processing QuestionSet: $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent

            try {
                $interview = New-HydrationAnswerSet -LoopId $loopId -QuestionsFilePath $questionsFilePath -UseUtc:$UseUtc -LogFilePath $logFilePath  -TerminalWidth:$TerminalWidth -ErrorAction Stop
            }
            catch {
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Failed to process QuestionSet $loopId"  -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
                Write-Error "Error in the interview process for $loopId, please review the error message and rerun the process."
                return
            }
            Write-HydrationLogFile -EntryType answerSetProvided -EntryData "$($interview | Convertto-Json -depth 100 -compress)" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            Write-Host "`nQuestion Set is complete, responses outlined below..." -ForegroundColor Yellow
            foreach ($intKey in $interview.keys) {
                $allInterviewAnswers.Add($intKey, $interview.$intKey)
                $testSummarySeparator = "-"
                $hashString = $( -join ($intKey, " ", ($testSummarySeparator * ($TerminalWidth - ($intKey.Length + $($interview.$intKey).Length + 2))), " ", $($interview.$intKey)))
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            }
            Remove-Variable loopId -ErrorAction SilentlyContinue
            Remove-Variable loopNotes -ErrorAction SilentlyContinue
            New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime 
        }
        else {
            $allInterviewAnswers.Add("pipelineCustomPath", "NotApplicable")
        }
        # Output Answer File
        $writeAnswerFile = $stageBlocks.writeAnswerFile
        New-HydrationSeparatorBlock @writeAnswerFile
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "File Location: $AnswerFilePath"-LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        try {
            $allInterviewAnswers | ConvertTo-Json -Depth 100 | Set-Content -Path $AnswerFilePath -Force
        }
        catch {
            Write-Error "Unable to write the answer file to $AnswerFilePath. Please ensure that you have write access to the location and try again. This was tested during the preliminary checks, so this is an odd situation. It is possible that a write lock, or some other lock, has occurred."
            return
        }
        
        # Summary separator block
        $displayAnswerData = $stageBlocks.displayAnswerData
        New-HydrationSeparatorBlock @displayAnswerData
        Write-HydrationLogFile -EntryType newStage -EntryData $displayAnswerData.DisplayText -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
    }

    # Display Summary
    $testSummarySeparator = "-"
    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Summary:" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
    foreach ($hashkey in $allInterviewAnswers.keys) {
        $hashString = $( -join ($hashKey, " ", ($testSummarySeparator * ($TerminalWidth - ($hashKey.Length + $($allInterviewAnswers.$hashKey).Length + 2))), " ", $($allInterviewAnswers.$hashKey)))
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
    }
    New-HydrationContinuePrompt -Interactive:$Interactive -SleepTime:$sleepTime

    ################################################################################
    # Execute hydration process
    Clear-Host
    $blockData = $stageBlocks.beginHydrationProcess
    New-HydrationSeparatorBlock @blockData
    Write-HydrationLogFile -EntryType newStage -EntryData "Hydrating EPAC based on the answers provided below:" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
    foreach ($hashkey in $allInterviewAnswers.keys) {
        $hashString = $( -join ($hashKey, " ", ($testSummarySeparator * ($TerminalWidth - ($hashKey.Length + $($allInterviewAnswers.$hashKey).Length + 2))), " ", $($allInterviewAnswers.$hashKey)))
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$hashString" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
    }

    #########################
    # Create Definitions Folder Structure

    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Creating Definitions folder structure..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
    try {
        New-HydrationDefinitionsFolder -DefinitionsRootFolder $DefinitionsRootFolder -ErrorAction Stop
    }
    catch {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData $Error[0].Exception.Message -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Unable to create Definitions folder. Please ensure that you have write access to $(Get-Location) and try again." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Use answer file at $AnswerFilePath to rerun the script without prompting for questions to retry this process once the problem is resolved." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        return
    }
    Write-Host "    Definitions folder structure has been validated..." -ForegroundColor Green

    #########################
    # Create Global Settings File 
    # Generate Environment List

    $allInterviewAnswers.initialTenantId = (Get-AzContext).tenant.id
    $allInterviewAnswers.initialTenantCloud = (Get-AzContext).environment.name
    $allInterviewAnswers.initialTenantIntermediateRoot = $TenantIntermediateRoot
    $globalSettingsInputs = [ordered]@{
        PacOwnerId                 = $allInterviewAnswers.pacOwnerId
        DefinitionsRootFolder      = $DefinitionsRootFolder
        ManagedIdentityLocation    = $allInterviewAnswers.managedIdAssignmentLocation
        MainPacSelector            = $allInterviewAnswers.mainTenantMainPacSelectorName
        EpacPacSelector            = "epac-dev" # TODO: Improvement, add a question to the mainpacselector loop for the epacPacSelector
        Cloud                      = (Get-AzContext).environment.name # This never need not be prompted, choice of initialTenantId will choose this implicitly
        TenantId                   = $allInterviewAnswers.initialTenantId
        MainDeploymentRoot         = $allInterviewAnswers.initialTenantIntermediateRoot
        EpacDevelopmentRoot        = $allInterviewAnswers.EpacDevelopmentRoot
        Strategy                   = 'ownedOnly' # This is kept at ownedOnly on purpose. People should be comfortable enough with the deployment to update this before changing to full to help prevent accidents
        # RepoRoot                   = $(Resolve-Path $DefinitionsRootFolder | Split-Path -Parent)
        LogFilePath                = $logFilePath
        UseUtc                     = $UseUtc
        KeepDfcSecurityAssignments = $false # TODO: Improvement, add a question to the mainpacselector loop for the dfcSecurityAssignments
    }
    # TODO: Improvement, add a question to main loop that enables a second loop that can be run multiple times to generate additional environments to add here in a loop
    #       Use a list of hashtable input (AdditionalPacSelectors) to add additional environments to the global settings file
    #       $additionalEnvironments = @{$i=@{same block as above},$i+n=@{same block as above}}
    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Creating Global Settings file..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
    try {
        $null = New-HydrationGlobalSettingsFile @globalSettingsInputs  -ErrorAction Stop
    }
    catch {
        Write-Error "Unable to create global-settings file. This is likely a flaw in the choices made above that should have been caught in earlier tests. Please retain your answer file and report this to the EPAC team, and attemp this process again."
        return
    }


    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Creating Pipeline..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
    Remove-Variable usePipelineCustomPath -ErrorAction SilentlyContinue
    if ($allInterviewAnswers.pipelineCustomPath -eq "NotApplicable") {
        try {
            New-PipelinesFromStarterKit -StarterKitFolder $StarterKit `
                -PipelineType $allInterviewAnswers.pipelinePlatform `
                -BranchingFlow $allInterviewAnswers.pipelineFlow `
                -ScriptType $allInterviewAnswers.codeExecutionType `
                -ErrorAction Stop
        }
        catch {
            Write-Error "Unable to create pipeline. This is likely a flaw in the choices made above that should have been caught in earlier tests. Please retain your answer file and report this to the EPAC team, and attemp this process again."
            return
        }
    }
    else {
        try {
            New-PipelinesFromStarterKit -StarterKitFolder $StarterKit `
                -PipelinesFolder:$usePipelineCustomPath `
                -PipelineType $allInterviewAnswers.pipelinePlatform `
                -BranchingFlow $allInterviewAnswers.pipelineFlow `
                -ScriptType $allInterviewAnswers.codeExecutionType `
                -ErrorAction Stop
        }
        catch {
            Write-Error "Unable to create pipeline. This is likely a flaw in the choices made above that should have been caught in earlier tests. Please retain your answer file and report this to the EPAC team, and attemp this process again."
            return
        }

    }


    ## Build MG Structure
    if ($allInterviewAnswers.createMainIntermediateRoot -eq "Yes") {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Creating Main Intermediate Root..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        do{
            try{
                New-AzManagementGroup -GroupName $allInterviewAnswers.initialTenantIntermediateRoot -ErrorAction Stop
            }
            catch{
                $AzMgRetry = $true
            }
            if(Get-AzManagementGroupRestMethod -GroupId $allInterviewAnswers.initialTenantIntermediateRoot){
                $AzMgRetry = $false
            }

        }until($AzMgRetry -eq $false)
    }
    if ($allInterviewAnswers.createMainCaf3Hierarchy -eq "Yes") {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Creating Main CAF3 Management Groups..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        New-HydrationCaf3Hierarchy -DestinationRootName $allInterviewAnswers.initialTenantIntermediateRoot -Prefix $allInterviewAnswers.mainCaf3Prefix -Suffix $allInterviewAnswers.maincaf3Suffix -ErrorAction Stop
    }
    ## Build EPAC MG Structure
    if (!($skipEpacMgDeploy)) {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Creating Epac Management Groups in $(-join($allInterviewAnswers.epacPrefix,$allInterviewAnswers.initialTenantIntermediateRoot,$allInterviewAnswers.epacSuffix)), a child of $($allInterviewAnswers.epacParent)..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        Copy-HydrationManagementGroupHierarchy -SourceGroupName $allInterviewAnswers.initialTenantIntermediateRoot -DestinationParentGroupName $allInterviewAnswers.epacParent -Prefix:$allInterviewAnswers.epacPrefix -Suffix:$allInterviewAnswers.epacSuffix | Out-Null
    }
    ## Import Existing Policy Assignments (if applicable)
    if ($allInterviewAnswers.importExistingPolicies -eq "Yes") {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Importing Existing Policy Assignments..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Exporting existing content for PacSelector `'$($allInterviewAnswers.mainTenantMainPacSelectorName)`', for which the root is defined as $($allInterviewAnswers.initialTenantIntermediateRoot)" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        Export-AzPolicyResources -DefinitionsRootFolder $DefinitionsRootFolder -ExemptionFiles 'csv' -FileExtension 'jsonc' -IncludeAutoAssigned -IncludeChildScopes -InputPacSelector $allInterviewAnswers.mainTenantMainPacSelectorName -Mode 'export' -OutputFolder $Output -ErrorAction Stop
        $fpath = Join-Path $Output "Export" "Definitions"
        if (!(Test-Path $fpath)) {
            Write-Error "Unable to find the folder $fpath. You should go to https://portal.azure.com and confirm whether or not assignments exist that are assigned within the referenced scope $($answerFile.initialTenantIntermediateRoot) and its children."
            $noExport = Read-Host "Type 'Confirmed' and press enter to continue, otherwise simply press enter to quit..."
            if (!($noExport -eq "Confirmed")) {
                {
                    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "You have confirmed that the export does not contain your contents. Confirm access, and run the script again, choosing to use the answer file at $answerFile." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
                }
            }
        }
        elseif (Test-Path $fpath) {
            $nonAssignmentExportFolders = Get-ChildItem $fpath -Directory -Exclude policyAssignments
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Copying $($nonAssignmentExportFolders.count) non-assignment content to definitions folder..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
            if ($nonAssignmentExportFolders.count -gt 0) {
                foreach ($sourceDir in $nonAssignmentExportFolders) {
                    $updatedFiles = Get-ChildItem -Path $sourceDir -Recurse -Include "*.json", "*.jsonc", '*.csv'
                    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Copying content from $sourceDir to $DefinitionsRootFolder" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
                    foreach ($uFile in $updatedFiles) {
                        # Calculate the relative path of the item
                        $relativePath = $uFile.FullName.Substring($(Split-Path $sourceDir.FullName).Length + 1)
                        
                        # Create the full destination path
                        $destinationPath = Join-Path -Path $DefinitionsRootFolder -ChildPath $relativePath

                        # Create the necessary destination directories
                        $destinationDirPath = Split-Path -Path $destinationPath
                        if (!(Test-Path -Path $destinationDirPath)) {
                            $null = New-Item -Path $destinationDirPath -ItemType Directory
                            Write-HydrationLogFile -EntryType logEntryDataAsPresented `
                                -EntryData "        Created $destinationDirPath" `
                                -LogFilePath $logFilePath `
                                -UseUtc:$UseUtc `
                                -Silent
                        }
                        # Copy the file or directory
                        Copy-Item -Path $uFile.FullName -Destination $destinationPath -Force
                        Write-HydrationLogFile -EntryType logEntryDataAsPresented `
                            -EntryData "        Copied $uFile to $destinationPath" `
                            -LogFilePath $logFilePath `
                            -UseUtc:$UseUtc `
                            -Silent
                        if(!(Test-Path -Path $destinationPath)) {
                            Write-HydrationLogFile -EntryType logEntryDataAsPresented `
                                -EntryData "    Failed to copy $uFile to $destinationPath, this should be copied manually or the task should be run again." `
                                -LogFilePath $logFilePath `
                                -UseUtc:$UseUtc `
                                -ForegroundColor Red
                        }
                    }
                }
            }
        }
        Remove-Variable noExport -ErrorAction SilentlyContinue
    }

    # Add Audit standards at root of hierarchies
    if ($allInterviewAnswers.importPciDssPolicies -eq "Yes" -or $allInterviewAnswers.importMcsbPolicies -eq "Yes" -or $allInterviewAnswers.importNist80053Policies -eq "Yes") {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Adding Specified Compliance Standards" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        $auditStandardList = @()
        if ($allInterviewAnswers.importPciDssPolicies -eq "Yes") {
            $auditStandardList += "/providers/Microsoft.Authorization/policySetDefinitions/c676748e-3af9-4e22-bc28-50feed564afb"
        }
        if ($allInterviewAnswers.importMcsbPolicies -eq "Yes") {
            $auditStandardList += "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
        }
        if ($allInterviewAnswers.importNist80053Policies -eq "Yes") {
            $auditStandardList += "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f"
        }
        foreach ($polSet in $auditStandardList) {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Exporting $polSet" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
            Export-PolicyToEPAC -PolicySetDefinitionId $polSet -OutputFolder $(Join-Path $Output "NewExportedAssignments") -AutoCreateParameters $TRUE -UseBuiltIn $TRUE -Scope $allInterviewAnswers.initialTenantIntermediateRoot -PacSelector $allInterviewAnswers.mainTenantMainPacSelectorName 
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Copying to  $(Join-Path $Output "NewExportedAssignments" "Export" "policyAssignments")" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
            Copy-Item -Path $(Join-Path $Output "NewExportedAssignments" "Export" "policyAssignments") `
                -Destination $(Join-Path $Output  "export" "definitions") `
                -Recurse `
                -Force            
        }
    }
    # Copy the updated assignments to the definitions folder 
    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Updating exported and newly created assignments with epac-dev pacSelector information based on assignments in PacSelector `'$($allInterviewAnswers.mainTenantMainPacSelectorName)...`'" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
    if($(Get-ChildItem $(Join-Path $Output 'export' 'definitions' 'policyAssignments') -ErrorAction SilentlyContinue).count -lt 1) {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    No exported assignments found, skipping assignment update..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
    }else{
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Adding EPAC pacSelector 'epac-dev' to assignments based on current scope..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        New-HydrationAssignmentPacSelector -SourcePacSelector $allInterviewAnswers.mainTenantMainPacSelectorName -NewPacSelector 'epac-dev' -MGHierarchyPrefix:$allInterviewAnswers.epacPrefix -MGHierarchySuffix:$allInterviewAnswers.epacSuffix -Definitions $(Join-Path $Output 'export' 'Definitions') -Output $Output -ErrorAction Stop
    }
    $updatedAssignmentList = Get-ChildItem -Path $(Join-Path $Output "UpdatedAssignments") -Recurse -Include "*.json", "*.jsonc" -ErrorAction SilentlyContinue
    if ($updatedAssignmentList.count -gt 0) {
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Copying updated $($UpdatedAssignmentList.count) assignments to definitions folder..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Copying new content to $DefinitionsRootFolder" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
        $destinationPath = Join-Path -Path $DefinitionsRootFolder -ChildPath "policyAssignments"
        if (!(Test-Path -Path $destinationPath)) {
            $null = New-Item -Path $destinationPath -ItemType Directory
        }
        foreach ($assignment in $updatedAssignmentList) {
            Copy-Item -Path $assignment.FullName -Destination $destinationPath
            if(Test-Path $(Join-Path $destinationPath $assignment.Name)){
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Copied $assignment to $destinationPath" -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent
            }
            else{
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "    Failed to copy $($assignment.fullname) to $(Join-Path $destinationPath $assignment.Name)" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
            }
        }
    }
    else{
        Write-HydrationLogFile -EntryType logEntryDataAsPresented `
            -EntryData "    No updated assignments found, skipping assignment update, but it is recommended that that you consider running this again with choices that include generation of an assignment so you have a template to review..." `
            -LogFilePath $logFilePath `
            -UseUtc:$UseUtc `
            -ForegroundColor Yellow
    }
        


    ################################################################################
    # Test in EPAC-Dev
    New-HydrationSeparatorBlock -DisplayText "End Hydration Process" -Location Bottom
    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Hydration process complete" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Magenta

    ################################################################################
    # Test in EPAC-Dev

    New-HydrationSeparatorBlock -DisplayText "Deploy to epac-dev" -Location Top

    Write-Host "These stepes require that the Az and EnterprisePolicyAsCode modules be available" -ForegroundColor Yellow
    Write-Host "When you are ready to deploy the changes to epac-dev, please perform the following tasks to complete deployment to the 'epac-dev' pacSelector:" -ForegroundColor Yellow
    Write-Host "    Build-DeploymentPlans -PacEnvironmentSelector 'epac-dev' -OutputFolder $Output -DefinitionsRootFolder $DefinitionsRootFolder"

    Write-Host "`nOnce this is complete, begin updating your pipeline environment to test deployment to the epac-dev environment via pipeline..." -ForegroundColor Yellow
    Write-Host "    General Guidance: https://azure.github.io/enterprise-azure-policy-as-code/ci-cd-overview/"
    Write-Host "    Azure DevOps: https://azure.github.io/enterprise-azure-policy-as-code/ci-cd-ado-pipelines/"
    Write-Host "    GitHub Actions: https://azure.github.io/enterprise-azure-policy-as-code/ci-cd-github-actions/"
}

