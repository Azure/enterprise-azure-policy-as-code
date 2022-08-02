#Requires -PSEdition Core

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $outputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Suppresses prompt for confirmation of each file in interactive mode")]
    [switch] $suppressConfirmation
)

#region Script Dot sourcing

# Common Functions
. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Switch-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-ParameterNameFromValueString.ps1"
. "$PSScriptRoot/../Helpers/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Helpers/Split-AssignmentIdForAzCli.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

# Documentation Functions
. "$PSScriptRoot/../Helpers/Get-PolicyInitiativeInfos.ps1"
. "$PSScriptRoot/../Helpers/Get-AssignmentsInfo.ps1"
. "$PSScriptRoot/../Helpers/Convert-PolicyInitiativeDefinitionsToInfo.ps1"
. "$PSScriptRoot/../Helpers/Convert-AssignmentsInfoToFlatPolicyList.ps1"
. "$PSScriptRoot/../Helpers/Convert-EffectToOrdinal.ps1"
. "$PSScriptRoot/../Helpers/Convert-EffectToShortForm.ps1"
. "$PSScriptRoot/../Helpers/Convert-EffectToString.ps1"
. "$PSScriptRoot/../Helpers/Convert-OrdinalToEffectDisplayName.ps1"
. "$PSScriptRoot/../Helpers/Convert-ParametersToString.ps1"
. "$PSScriptRoot/../Helpers/Convert-ListToToCsvRow.ps1"
. "$PSScriptRoot/../Helpers/Out-InitiativeDocumentationToFile.ps1"
. "$PSScriptRoot/../Helpers/Out-PolicyAssignmentDocumentationPerEnvironmentToFile.ps1"
. "$PSScriptRoot/../Helpers/Out-PolicyAssignmentDocumentationAcrossEnvironmentsToFile.ps1"

#endregion dot sourcing

#region Initialize

$InformationPreference = 'Continue'
$globalSettings = Get-GlobalSettings -definitionsRootFolder $definitionsRootFolder -outputFolder $outputFolder
$definitionsFolder = $globalSettings.documentationDefinitionsFolder
$pacEnvironments = $globalSettings.pacEnvironments
$outputPath = "$($globalSettings.outputFolder)/AzPolicyDocumentation"
if (-not (Test-Path $outputPath)) {
    New-Item $outputPath -Force -ItemType directory
}


# Caching information to optimize different outputs
$cachedPolicyInitiativeInfos = @{}
$cachedAssignmentInfos = @{}
$currentPacEnvironmentSelector = ""
$pacEnvironment = $null

#endregion Initialize

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Reading documentation definitions in folder '$definitionsFolder'"
Write-Information "==================================================================================================="
$filesRaw = @()
$filesRaw += Get-ChildItem -Path $definitionsFolder -Recurse -File -Filter "*.jsonc"
$filesRaw += Get-ChildItem -Path $definitionsFolder -Recurse -File -Filter "*.json"
$files = @()
$files += ($filesRaw  | Sort-Object -Property Name)
if ($files.Length -gt 0) {
    Write-Information "Number of documentation definition files = $($files.Length)"
}
else {
    Write-Information "There aren't any documentation definition files in the folder provided!"
}

$processAllFiles = -not $interactive -or $suppressConfirmation.IsPresent -or $files.Length -eq 1
foreach ($file in $files) {
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Reading and Processing '$($file.Name)'"
    Write-Information "==================================================================================================="

    $processThisFile = $processAllFiles
    if (-not $processAllFiles) {
        $title = "Process documentation definition file '$($file.Name)'"
        $message = "Do you want to process the file?"

        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
            "Process the current file."
        $all = New-Object System.Management.Automation.Host.ChoiceDescription "&All", `
            "Process remaining files files in folder '$definitionsFolder'."
        $skip = New-Object System.Management.Automation.Host.ChoiceDescription "&Skip", `
            "Skip processing this file."
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $skip, $all)
        $result = $Host.UI.PromptForChoice($title, $message, $options, 0)
        switch ($result) {
            0 {
                $processThisFile = $true
            }
            1 {
                $processThisFile = $false
                Write-Information "***************************************************************************************************"
                Write-Information "***************************************************************************************************"
                Write-Information "** Skipping file '$($file.Name)'"
                Write-Information "***************************************************************************************************"
                Write-Information "***************************************************************************************************"
                Write-Information ""
                Write-Information ""
            }
            2 {
                $processThisFile = $true
                $processAllFiles = $true
            }
        }
    }

    if ($processThisFile) {
        $json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        if (-not (Test-Json $json)) {
            Write-Error "The Json file '$($file.Name)' is not valid." -ErrorAction Stop
        }
        $documentationSpec = $json | ConvertFrom-Json

        if (-not ($documentationSpec.documentAssignments -or $documentationSpec.documentInitiatives)) {
            Write-Error "Json document must contain 'documentAssignments' and/or 'documentInitiatives' element(s)." -ErrorAction Stop
        }

        # Process instructions to document Assignments
        if ($documentationSpec.documentAssignments) {
            $documentAssignments = $documentationSpec.documentAssignments
            $environmentCategories = $documentAssignments.environmentCategories

            # Process assignments for every environmentCategory specified
            [hashtable] $assignmentsDetailsByEnvironmentCategory = @{}
            foreach ($environmentCategoryEntry in $environmentCategories) {
                if (-not $environmentCategoryEntry.pacEnvironment) {
                    Write-Error "Json document does not contain the required 'pacEnvironment' element." -ErrorAction Stop
                }
                # Load pacEnvironment
                $pacEnvironmentSelector = $environmentCategoryEntry.pacEnvironment
                Write-Information ""
                if ($currentPacEnvironmentSelector -ne $pacEnvironmentSelector) {
                    $currentPacEnvironmentSelector = $pacEnvironmentSelector
                    Write-Information "==================================================================================================="
                    Write-Information "Policy as Code environment (pacEnvironment) '$($pacEnvironmentSelector)'"
                    Write-Information "==================================================================================================="
                    Write-Information ""
                    $pacEnvironment = Switch-PacEnvironment `
                        -pacEnvironmentSelector $currentPacEnvironmentSelector `
                        -pacEnvironments $pacEnvironments `
                        -interactive $interactive
                }

                # Retrieve Policies and Initiatives for current pacEnvironment from cache or from Azure
                $policyInitiativeInfo = Get-PolicyInitiativeInfos `
                    -pacEnvironmentSelector $currentPacEnvironmentSelector `
                    -pacEnvironment $pacEnvironment `
                    -cachedPolicyInitiativeInfos $cachedPolicyInitiativeInfos

                # Retrieve assignments and process informatiion or retrieve from cache is assignment previoously processed
                $assignmentArray = $environmentCategoryEntry.representativeAssignments
                Write-Information "==================================================================================================="
                Write-Information "Retrieving and procesing Assignments for environment category '$($environmentCategoryEntry.environmentCategory)'"
                Write-Information "==================================================================================================="

                $assignmentsInfo = Get-AssignmentsInfo `
                    -pacEnvironmentSelector $currentPacEnvironmentSelector `
                    -assignmentArray $assignmentArray `
                    -policyInitiativeInfo $policyInitiativeInfo `
                    -cachedAssignmentInfos $cachedAssignmentInfos

                # Flatten Policy lists in Assignments and reconcile the most restrictive effect for each Policy
                $flatPolicyList = Convert-AssignmentsInfoToFlatPolicyList `
                    -assignmentArray $assignmentArray `
                    -assignmentsInfo $assignmentsInfo

                # Store results of processing and falttening for use in document generation
                $assignmentsDetailsByEnvironmentCategory.Add($environmentCategoryEntry.environmentCategory, @{
                        pacEnvironmentSelector = $currentPacEnvironmentSelector
                        scopes                 = $environmentCategoryEntry.scopes
                        assignmentArray        = $assignmentArray
                        assignmentsInfo        = $assignmentsInfo
                        flatPolicyList         = $flatPolicyList
                    }
                )
            }

            # Build documents
            Write-Information ""
            Write-Information "==================================================================================================="
            Write-Information "Generate Policy Assignment documents"
            Write-Information "==================================================================================================="
            $documentationSpecifications = $documentAssignments.documentationSpecifications
            foreach ($documentationSpecification in $documentationSpecifications) {
                $documentationType = $documentationSpecification.type
                switch ($documentationType) {
                    effectsPerEnvironment {
                        Out-PolicyAssignmentDocumentationPerEnvironmentToFile `
                            -outputPath $outputPath `
                            -documentationSpecification $documentationSpecification `
                            -assignmentsDetailsByEnvironmentCategory $assignmentsDetailsByEnvironmentCategory
                    }
                    effectsAcrossEnvironments {
                        Out-PolicyAssignmentDocumentationAcrossEnvironmentsToFile `
                            -outputPath $outputPath `
                            -documentationSpecification $documentationSpecification `
                            -assignmentsDetailsByEnvironmentCategory $assignmentsDetailsByEnvironmentCategory
                    }
                    Default {
                        Write-Error "Unknown documentType '$documentationType' encountered" -ErrorAction Stop
                    }
                }
            }
        }

        $documentInitiatives = $documentationSpec.documentInitiatives
        if ($documentInitiatives -and $documentInitiatives.Count -gt 0) {
            Write-Information ""
            Write-Information "==================================================================================================="
            Write-Information "Generate Initiative documents"
            Write-Information "==================================================================================================="
            foreach ($documentInitiativeEntry in $documentInitiatives) {
                $pacEnvironmentSelector = $documentInitiativeEntry.pacEnvironment
                if (-not $pacEnvironmentSelector) {
                    Write-Error "documentInitiative entry does not specify pacEnvironment" -ErrorAction Stop
                }
                $fileNameStem = $documentInitiativeEntry.fileNameStem
                if (-not $fileNameStem) {
                    Write-Error "documentInitiative entry does not specify fileNameStem" -ErrorAction Stop
                }
                $title = $documentInitiativeEntry.title
                if (-not $title) {
                    Write-Error "documentInitiative entry does not specify title" -ErrorAction Stop
                }
                $initiatives = $documentInitiativeEntry.initiatives
                if (-not $initiatives -or $initiatives.Count -eq 0) {
                    Write-Error "documentInitiative entry does not specify an initiatives array or initiatives array is empty" -ErrorAction Stop
                }

                if (-not $cachedPolicyInitiativeInfos.ContainsKey($pacEnvironmentSelector)) {
                    if ($currentPacEnvironmentSelector -ne $pacEnvironmentSelector) {
                        $currentPacEnvironmentSelector = $pacEnvironmentSelector
                        Write-Information "==================================================================================================="
                        Write-Information "Policy as Code environment (pacEnvironment) '$($pacEnvironmentSelector)'"
                        Write-Information "==================================================================================================="
                        Write-Information ""
                        $pacEnvironment = Switch-PacEnvironment `
                            -pacEnvironmentSelector $currentPacEnvironmentSelector `
                            -pacEnvironments $pacEnvironments `
                            -interactive $interactive

                    }
                }

                # Retrieve Policies and Initiatives for current pacEnvironment from cache or from Azure
                $policyInitiativeInfo = Get-PolicyInitiativeInfos `
                    -pacEnvironmentSelector $pacEnvironmentSelector `
                    -pacEnvironment $pacEnvironment `
                    -cachedPolicyInitiativeInfos $cachedPolicyInitiativeInfos

                # Print documentation
                Out-InitiativeDocumentationToFile `
                    -outputPath $outputPath `
                    -fileNameStem $fileNameStem `
                    -pacEnvironmentSelector $pacEnvironmentSelector `
                    -title $title `
                    -initiatives $initiatives `
                    -policyInitiativeInfo $policyInitiativeInfo
            }
        }
    }
}
