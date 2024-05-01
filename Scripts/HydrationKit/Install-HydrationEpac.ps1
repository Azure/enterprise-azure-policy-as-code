<#
.SYNOPSIS
    This function deploys Enterprise Policy as Code locally, and configures the repo to be uploaded to the platform of your choice.

.DESCRIPTION
    The Install-HydrationEpac function deploys the Enterprise Policy as Code. It takes three optional parameters: Definitions, StarterKit, and AnswerFilePath. 

.PARAMETER Definitions
    The path to the Definitions directory. Defaults to "./Definitions".

.PARAMETER StarterKit
    The path to the StarterKit directory. Defaults to "./StarterKit".

.PARAMETER AnswerFilePath
    The path to the Answer file. This parameter is optional and does not have a default value.

.EXAMPLE
    Install-HydrationEpac

    This example deploys the Enterprise Policy as Code using the default directories, which is appropriate if being run from the root of the new repo.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]
    $Definitions = "./Definitions",
    [Parameter(Mandatory = $false)]
    [string]
    $StarterKit = "./StarterKit",
    [Parameter(Mandatory = $false)]
    [string]
    $AnswerFilePath
)
$InformationPreference = "Continue"
$repoRootPath = Split-Path $Definitions
$output = Join-Path $repoRootPath "Output"
Write-Information "Beginning Deployment of Enterprise Policy as Code..."
Write-Warning "This script is currently in Beta release. Please report any issues to the EPAC team."
    
# Import critical modules
$lowestSupportedVersion = "10.1.11"
Update-HydrationModuleToSupportedVersion -ModuleName "EnterprisePolicyAsCode" -LowestSupportedVersion $lowestSupportedVersion
# Import-Module EnterprisePolicyAsCode -Force

# Create critical paths
foreach ($path in @($output, $definitions)) {
    if (!(Test-Path $path)) {
        Write-Information "Creating $path..."
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}
if (!($AnswerFilePath)) {
    try {
        $answers = New-HydrationAnswerFile  -Output:$output -ErrorAction Stop
        $AnswerFilePath = (Get-ChildItem $answers.outputPath -Include "answerFile.json").FullName
        Write-Information "`n`nYou can rerun this referencing the answer file at $AnswerFilePath if you wish to avoid the interactive prompts and simply update the data with new values.`n`n"
    }
    catch {
        Write-Error $error[0].Exception.Message
        exit
    }
}
else {
    if (Test-Path $AnswerFilePath) {
        $answers = Get-Content $AnswerFilePath | ConvertFrom-Json -Depth 10 -AsHashtable
    }
    else {
        $fileAnswer = Read-Host "The answer file at $AnswerFilePath does not exist. Would you like to create it? (y/n)"
        If ($fileAnswer -eq "y") {
            $answers = New-HydrationAnswerFile  -Output:$output
        }
        else {
            Write-Error "Please correct your path for the answer file and rerun the script."
            exit
        }
    }
}

## Create EPAC Directory Structure
Write-Information "`n################################################################################"
Write-Information "Creating repo Definitions folder...`n"
try {
    New-HydrationDefinitionFolder -DefinitionsRootFolder $definitions -ErrorAction Stop
}
catch {
    Write-Error "Unable to create Definitions folder. Please ensure that you have write access to $(Get-Location) and try again."
    Write-Error "Use answer file at $AnswerFilePath to rerun the script without prompts should you run into a rights issue, or something else that might require this to be run again without updating any values."
    exit
}
try {
    $null = New-HydrationGlobalSettingsFile -Answers $answers -RepoRootPath $repoRootPath  -ErrorAction Stop
}
catch {
    Write-Error "Unable to create global-settings file. This is likely a flaw in the choices made above that should have been caught in earlier tests. Please retain your answer file and report this to the EPAC team."
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $errorPath = Join-Path $output "answerfile_failed-$timestamp.json"
    Copy-Item $AnswerFilePath -Destination $errorPath
    Write-Error "Please attempt to run the script again, we have retained the settings for the failed run at $errorPath."
    exit
}
## Create EPAC DevOps Pipeline (if applicable)
Write-Information "`n################################################################################"
Write-Information "Creating Pipeline...`n"
switch ($answers.platform) {
    "ado" {
        try {
            $pipeline = New-PipelinesFromStarterKit -StarterKitFolder $StarterKit -PipelinesFolder:$answers.pipelinePath -PipelineType $answers.pipelineType -BranchingFlow $answers.branchingFlow -ScriptType $answers.scriptType -ErrorAction Stop

        }
        catch {
            Write-Error "Unable to create pipeline. Please rerun hydration and confirm the pipeline responses in the New-HydrationAnswerFile cmdlet interview."
            exit
        }
        # TODO: Add API calls to configure ADO configuration and repo   
    }
    "github" {

        try {
            $pipeline = New-PipelinesFromStarterKit -StarterKitFolder $StarterKit -PipelinesFolder:$answers.pipelineFolder -PipelineType $answers.pipelineType -BranchingFlow $answers.branchingFlow -ScriptType $answers.scriptType -ErrorAction Stop
        }
        catch {
            Write-Error "Unable to create pipeline. Please rerun hydration and confirm the pipeline responses in the New-HydrationAnswerFile cmdlet interview."
            exit
        }
        # TODO: Add API calls to configure github configuration and repo        
    }
    "other" {
        Write-Information "Pipeline will not be created. Please review the steps in the pipelines under $pipelineSource to help build your own process.`n"
    }
    default {
        Write-Error "Invalid response. This is a bug. Check to see if a new valid type was added and the switch was not updated properly.`n"
        return
    }
}
############# Populate Definitions Sub-Directories
## Import PCI-DSS (if applicable)
if ($answers.usePciBaseline) {
    Write-Information "`n################################################################################"
    Write-Information "We will now create the PCI DSS Policy Set to evaluate your security posture...`n"
    $pciScope = [ordered]@{
        outputJson = Join-Path $definitions "policyAssignments" "pci-dss4.jsonc"
        outputCsv  = Join-Path $definitions "policyAssignments" "pci-dss-effects.csv"
        Assignment = $(Get-Content (Join-Path $StarterKit "hkdefinitions" "policyAssignments" "pci-dss4.jsonc") | ConvertFrom-Json -depth 20)
        CsvData    = $(Import-Csv (Join-Path $StarterKit "hkdefinitions" "policyAssignments" "pci-dss-effects.csv"))
        answers    = $answers
    }
    Update-HydrationStarterKitAssignmentScope @pciScope
}
Remove-Variable pciScope
## Import Azure/Microsoft Security Baseline and NIST 800-53 (if applicable)
if ($answers.useEpacBaseline) {
    Write-Information "`n################################################################################"
    Write-Information "We will now create the Azure/Microsoft Security Baseline and NIST 800-53 Policy Set to evaluate your security posture...`n"
    $epbScope = [ordered]@{
        outputJson = Join-Path $definitions "policyAssignments" "security-baseline-assignments.jsonc"
        outputCsv  = Join-Path $definitions "policyAssignments" "security-baseline-parameters.csv"
        Assignment = $(Get-Content (Join-Path $StarterKit "hkdefinitions" "policyAssignments" "security-baseline-assignments.jsonc") | ConvertFrom-Json -depth 20)
        CsvData    = $(Import-Csv (Join-Path $StarterKit "hkdefinitions" "policyAssignments" "security-baseline-parameters.csv") )
        answers    = $answers
    }
    Update-HydrationStarterKitAssignmentScope @epbScope
}
Remove-Variable epbScope
## Import Existing Policy Assignments (if applicable)
if ($answers.useCurrent) {
    Write-Information "`n################################################################################"
    Write-Information "We will now import existing policy assignments in $intermediateRootGroupName into the EPAC definitions...`n"
    foreach ($env in $answers.environments.Keys) {
        if ($answers.environments.$env.intermediateRootGroupName -eq $answers.epacSourceGroupName) {
            Export-AzPolicyResources -IncludeChildScopes -InputPacSelector $answers.environments.$env.pacSelector -Mode Export -DefinitionsRootFolder $definitions -OutputFolder $output -ExemptionFiles csv -FileExtension jsonc -ErrorAction Stop
        }
    }
    $exportFolder = Join-Path $output "Export" "Definitions"
    $updatedAssignmtentsFolder = Join-Path $output "UpdatedAssignments"
    if (!(Test-Path $updatedAssignmtentsFolder)) {
        $null = New-Item -ItemType Directory -Path $updatedAssignmtentsFolder -Force
    }
    $exportedAssignments = (Get-ChildItem $(Join-Path $exportFolder "policyAssignments") -File "*.jsonc").FullName
    $SourcePacSelector = ($answers.environments.values | Where-Object { $_.intermediateRootGroupName -eq $answers.epacSourceGroupName }).pacSelector
    $NewPacSelector = ($answers.environments.values | Where-Object { $_.intermediateRootGroupName -eq $( -join ($answers.epacPrefix, $answers.epacSourceGroupName, $answers.epacSuffix)) }).pacSelector
    foreach ($assignment in $exportedAssignments) {
        New-HydrationAssignmentPacSelector -SourcePacSelector $SourcePacSelector -NewPacSelector $NewPacSelector -MGHierarchyPrefix $answers.epacPrefix -MGHierarchySuffix $answers.epacSuffix -Definitions $exportFolder -Output $output -ErrorAction Stop
    }
    Copy-Item -Path $($updatedAssignmtentsFolder + '/*') -Destination $(Join-Path $definitions "policyAssignments") -Recurse -Force
}
## Build EPAC MG Structure
Write-Information "`n################################################################################"
Write-Information "Duplicating $($answers.epacSourceGroupName) Management Group structure for your EPAC deployment under $($answers.epacParentGroupName)...`n"
Write-Information "    This will take some time, and will permanently alter your Management Group structure by adding a copy of your Intermediate Tenant Root group for EPAC to test against.`n"
Write-Information "    If you have already completed this process, you can skip this step by typing 'skip' at the prompt below.`n"
$continue1 = Read-Host "Press Enter to continue, or type 'skip' to bypass this step"
if (!($continue1 -eq "skip")) {
    Copy-HydrationManagementGroupHierarchy -SourceGroupName $answers.epacSourceGroupName -DestinationParentGroupName $answers.epacParentGroupName -Prefix:$answers.epacPrefix -Suffix:$answers.epacSuffix
}
################# TODO: Move this section back up to the assignment definition section when it is reintroduced

## Import ALZ CAF Policy Set (if applicable)
# TODO: This will be in the next revision, it requires we gather several new pieces of information for/from the answer file to complete the process
# if ($answers.useCaf) {
#     Write-Information "`n################################################################################"
#     Write-Information "We will now complete the ALZ CAF Policy Set import process..."
#     Sync-ALZPolicies -CloudEnvironment $answers.environments.($answers.environments.keys[0]).cloud -DefinitionsRootFolder $definitions -ErrorAction Stop
#     #TODO: Update assignment blocks if CAF MG names are not at ALZ defaults, will need the answer file to determine this, and if not it can be overridden with key(cafValue) tov value(environmentRealValue)
# }
# else {
#     ## Import EPAC Policy Set (NIST/MSB) (if applicable, this cannot be used with ALZ Import as the assignments conflict in our generic deployment)
#     if ($answers.useEpacBaseline) {
#         Write-Information "`n################################################################################"
#         Write-Information "We will now apply the NIST and MSB Policy Sets to evaluate your security posture..."
#         # TODO: Write a quick import function to manage the work in the next todo
#         # TODO: Import each from json, remove the environment targets, add one for each current environment, and output the assignment. 
#         # TODO: Copy CSV and update column headers for environment != epac-dev
#         # TODO: Update Tenant01 column to actual name
#         <#
#                 # Import the CSV file
#                 $data = Import-Csv -Path 'C:\path\to\your.csv'
#                 # Rename the column
#                 $data | Select-Object @{Name='NewColumnName'; Expression={$_.'OldColumnName'}}, * -ExcludeProperty 'OldColumnName' |
#                 Export-Csv 'C:\path\to\new.csv' -NoTypeInformation
#                 #>
#     }
# }
