<#
.SYNOPSIS 
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment.   

.PARAMETER definitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER outputFolder
    Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

.PARAMETER windowsNewLineCells
    Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell

.PARAMETER interactive
    Set to false if used non-interactive

.PARAMETER suppressConfirmation
    Suppresses prompt for confirmation to delete existing file in interactive mode

.EXAMPLE
    Build-PolicyDocumentation.ps1 -definitionsRootFolder "C:\PAC\Definitions" -outputFolder "C:\PAC\Output" -interactive
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment.

.EXAMPLE
    Build-PolicyDocumentation.ps1 -interactive
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment. The script prompts for the PAC environment and uses the default definitions and output folders.

.EXAMPLE
    Build-PolicyDocumentation.ps1 -definitionsRootFolder "C:\PAC\Definitions" -outputFolder "C:\PAC\Output" -interactive -suppressConfirmation
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment. The script prompts for the PAC environment and uses the default definitions and output folders. It suppresses prompt for confirmation to delete existing file in interactive mode.

.LINK
    https://azure.github.io/enterprise-azure-policy-as-code/#deployment-scripts
    https://azure.github.io/enterprise-azure-policy-as-code/operational-scripts/#build-policyassignmentdocumentationps1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $outputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell")]
    [switch] $windowsNewLineCells,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Suppresses prompt for confirmation of each file in interactive mode")]
    [switch] $suppressConfirmation
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

#region Initialize

$InformationPreference = 'Continue'
$globalSettings = Get-GlobalSettings -definitionsRootFolder $definitionsRootFolder -outputFolder $outputFolder
$definitionsFolder = $globalSettings.policyDocumentationsFolder
$pacEnvironments = $globalSettings.pacEnvironments
$outputPath = "$($globalSettings.outputFolder)/PolicyDocumentation"
if (-not (Test-Path $outputPath)) {
    New-Item $outputPath -Force -ItemType directory
}


# Caching information to optimize different outputs
$cachedPolicyResourceDetails = @{}
$cachedAssignmentsDetails = @{}
$currentPacEnvironmentSelector = ""
$pacEnvironment = $null

#endregion Initialize

Write-Information ""
Write-Information "==================================================================================================="s
Write-Information "Processing documentation definitions in folder '$definitionsFolder'"
Write-Information "==================================================================================================="
if (!(Test-Path $definitionsFolder -PathType Container)) {
    Write-Error "Policy documentation specification folder 'policyDocumentations not found.  This EPAC instance cannot generate documentation." -ErrorAction Stop
}

$filesRaw = @()
$filesRaw += Get-ChildItem -Path $definitionsFolder -Recurse -File -Filter "*.jsonc"
$filesRaw += Get-ChildItem -Path $definitionsFolder -Recurse -File -Filter "*.json"
$files = @()
$files += ($filesRaw  | Sort-Object -Property Name)
if ($files.Length -gt 0) {
    Write-Information "Number of documentation definition files = $($files.Length)"
}
else {
    Write-Error "No documentation definition files found!" -ErrorAction Stop
}

$processAllFiles = -not $interactive -or $suppressConfirmation -or $files.Length -eq 1
foreach ($file in $files) {

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
                Write-Information "Skipping file '$($file.Name)'"
            }
            2 {
                $processThisFile = $true
                $processAllFiles = $true
            }
        }
    }

    if ($processThisFile) {
        Write-Information "Reading and Processing '$($file.Name)'"
        $json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        if (-not (Test-Json $json)) {
            Write-Error "The JSON file '$($file.Name)' is not valid." -ErrorAction Stop
        }
        $documentationSpec = $json | ConvertFrom-Json

        if (-not ($documentationSpec.documentAssignments -or $documentationSpec.documentPolicySets)) {
            Write-Error "JSON document must contain 'documentAssignments' and/or 'documentPolicySets' element(s)." -ErrorAction Stop
        }

        $documentPolicySets = $documentationSpec.documentPolicySets
        if ($documentPolicySets -and $documentPolicySets.Count -gt 0) {
            $pacEnvironment = $null
            foreach ($documentPolicySetEntry in $documentPolicySets) {
                $pacEnvironmentSelector = $documentPolicySetEntry.pacEnvironment
                if (-not $pacEnvironmentSelector) {
                    Write-Error "documentPolicySet entry does not specify pacEnvironment." -ErrorAction Stop
                }

                $fileNameStem = $documentPolicySetEntry.fileNameStem
                if (-not $fileNameStem) {
                    Write-Error "documentPolicySet entry does not specify fileNameStem." -ErrorAction Stop
                }

                $title = $documentPolicySetEntry.title
                if (-not $title) {
                    Write-Error "documentPolicySet entry does not specify title." -ErrorAction Stop
                }

                if ($documentPolicySetEntry.initiatives) {
                    Write-Error "Legacy field `"initiatives`" used, change to `"policySets`"." -ErrorAction Stop
                }
                $policySets = $documentPolicySetEntry.policySets
                if (-not $policySets -or $policySets.Count -eq 0) {
                    Write-Error "documentPolicySet entry does not specify required policySets array entry." -ErrorAction Stop
                }

                $itemArrayList = [System.Collections.ArrayList]::new()
                if ($null -ne $policySets -and $policySets.Count -gt 0) {
                    foreach ($policySet in $policySets) {
                        $itemEntry = @{
                            shortName    = $policySet.shortName
                            itemId       = $policySet.id
                            policySetId  = $policySet.id
                            assignmentId = $null
                        }
                        $null = $itemArrayList.Add($itemEntry)
                    }
                }
                else {
                    Write-Error "documentPolicySet entry does not specify an policySets array or policySets array is empty" -ErrorAction Stop
                }
                $itemList = $itemArrayList.ToArray()

                $environmentColumnsInCsv = $documentPolicySetEntry.environmentColumnsInCsv

                if (-not $cachedPolicyResourceDetails.ContainsKey($pacEnvironmentSelector)) {
                    if ($currentPacEnvironmentSelector -ne $pacEnvironmentSelector) {
                        $currentPacEnvironmentSelector = $pacEnvironmentSelector
                        $pacEnvironment = Switch-PacEnvironment `
                            -pacEnvironmentSelector $currentPacEnvironmentSelector `
                            -pacEnvironments $pacEnvironments `
                            -interactive $interactive

                    }
                }

                # Retrieve Policies and PolicySets for current pacEnvironment from cache or from Azure
                $policyResourceDetails = Get-PolicyResourceDetails `
                    -pacEnvironmentSelector $pacEnvironmentSelector `
                    -pacEnvironment $pacEnvironment `
                    -cachedPolicyResourceDetails $cachedPolicyResourceDetails
                $policySetDetails = $policyResourceDetails.policySets

                $flatPolicyList = Convert-PolicySetsToFlatList `
                    -itemList $itemList `
                    -details $policySetDetails

                # Print documentation
                Out-PolicySetsDocumentationToFile `
                    -outputPath $outputPath `
                    -fileNameStem $fileNameStem `
                    -windowsNewLineCells:$windowsNewLineCells `
                    -title $title `
                    -itemList $itemList `
                    -environmentColumnsInCsv $environmentColumnsInCsv `
                    -policySetDetails $policySetDetails `
                    -flatPolicyList $flatPolicyList
            }
        }

        # Process instructions to document Assignments
        if ($documentationSpec.documentAssignments) {
            $documentAssignments = $documentationSpec.documentAssignments
            $environmentCategories = $documentAssignments.environmentCategories

            # Process assignments for every environmentCategory specified
            [hashtable] $assignmentsByEnvironment = @{}
            foreach ($environmentCategoryEntry in $environmentCategories) {
                if (-not $environmentCategoryEntry.pacEnvironment) {
                    Write-Error "JSON document does not contain the required 'pacEnvironment' element." -ErrorAction Stop
                }
                # Load pacEnvironment
                $pacEnvironmentSelector = $environmentCategoryEntry.pacEnvironment
                if ($currentPacEnvironmentSelector -ne $pacEnvironmentSelector) {
                    $currentPacEnvironmentSelector = $pacEnvironmentSelector
                    $pacEnvironment = Switch-PacEnvironment `
                        -pacEnvironmentSelector $currentPacEnvironmentSelector `
                        -pacEnvironments $pacEnvironments `
                        -interactive $interactive
                }

                # Retrieve Policies and PolicySets for current pacEnvironment from cache or from Azure
                $policyResourceDetails = Get-PolicyResourceDetails `
                    -pacEnvironmentSelector $currentPacEnvironmentSelector `
                    -pacEnvironment $pacEnvironment `
                    -cachedPolicyResourceDetails $cachedPolicyResourceDetails

                # Retrieve assignments and process information or retrieve from cache is assignment previously processed
                $assignmentArray = $environmentCategoryEntry.representativeAssignments

                $itemList, $assignmentsDetails = Get-AssignmentsDetails `
                    -pacEnvironmentSelector $currentPacEnvironmentSelector `
                    -assignmentArray $assignmentArray `
                    -policyResourceDetails $policyResourceDetails `
                    -cachedAssignmentsDetails $cachedAssignmentsDetails

                # Flatten Policy lists in Assignments and reconcile the most restrictive effect for each Policy
                $flatPolicyList = Convert-PolicySetsToFlatList `
                    -itemList $itemList `
                    -details $assignmentsDetails

                # Store results of processing and flattening for use in document generation
                $null = $assignmentsByEnvironment.Add($environmentCategoryEntry.environmentCategory, @{
                        pacEnvironmentSelector = $currentPacEnvironmentSelector
                        scopes                 = $environmentCategoryEntry.scopes
                        itemList               = $itemList
                        assignmentsDetails     = $assignmentsDetails
                        flatPolicyList         = $flatPolicyList
                    }
                )
            }

            # Build documents
            $documentationSpecifications = $documentAssignments.documentationSpecifications
            foreach ($documentationSpecification in $documentationSpecifications) {
                $documentationType = $documentationSpecification.type
                if ($null -ne $documentationType) {
                    Write-Information "Field documentationType ($($documentationType)) is deprecated"
                }
                Out-PolicyAssignmentDocumentationToFile `
                    -outputPath $outputPath `
                    -windowsNewLineCells:$windowsNewLineCells `
                    -documentationSpecification $documentationSpecification `
                    -assignmentsByEnvironment $assignmentsByEnvironment
            }
        }

    }
}
