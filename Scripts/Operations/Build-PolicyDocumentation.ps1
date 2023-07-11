<#
.SYNOPSIS 
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment.   

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFolder
    Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

.PARAMETER WindowsNewLineCells
    Formats CSV multi-Object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell

.PARAMETER Interactive
    Set to false if used non-Interactive

.PARAMETER SuppressConfirmation
    Suppresses prompt for confirmation to delete existing file in interactive mode

.EXAMPLE
    Build-PolicyDocumentation.ps1 -DefinitionsRootFolder "C:\PAC\Definitions" -OutputFolder "C:\PAC\Output" -Interactive
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment.

.EXAMPLE
    Build-PolicyDocumentation.ps1 -Interactive
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment. The script prompts for the PAC environment and uses the default definitions and output folders.

.EXAMPLE
    Build-PolicyDocumentation.ps1 -DefinitionsRootFolder "C:\PAC\Definitions" -OutputFolder "C:\PAC\Output" -Interactive -SuppressConfirmation
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment. The script prompts for the PAC environment and uses the default definitions and output folders. It suppresses prompt for confirmation to delete existing file in interactive mode.

.LINK
    https://azure.github.io/enterprise-azure-Policy-as-code/#deployment-scripts
    https://azure.github.io/enterprise-azure-Policy-as-code/operational-scripts/#build-Policyassignmentdocumentationps1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Formats CSV multi-Object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell")]
    [switch] $WindowsNewLineCells,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-Interactive")]
    [bool] $Interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Suppresses prompt for confirmation of each file in interactive mode")]
    [switch] $SuppressConfirmation
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

#region Initialize

$InformationPreference = 'Continue'
$globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder
$DefinitionsFolder = $globalSettings.policyDocumentationsFolder
$PacEnvironments = $globalSettings.pacEnvironments
$OutputPath = "$($globalSettings.outputFolder)/PolicyDocumentation"
if (-not (Test-Path $OutputPath)) {
    New-Item $OutputPath -Force -ItemType directory
}


# Caching information to optimize different outputs
$CachedPolicyResourceDetails = @{}
$CachedAssignmentsDetails = @{}
$currentPacEnvironmentSelector = ""
$PacEnvironment = $null

#endregion Initialize

Write-Information ""
Write-Information "==================================================================================================="s
Write-Information "Processing documentation definitions in folder '$DefinitionsFolder'"
Write-Information "==================================================================================================="
if (!(Test-Path $DefinitionsFolder -PathType Container)) {
    Write-Error "Policy documentation specification folder 'policyDocumentations not found.  This EPAC instance cannot generate documentation." -ErrorAction Stop
}

$filesRaw = @()
$filesRaw += Get-ChildItem -Path $DefinitionsFolder -Recurse -File -Filter "*.jsonc"
$filesRaw += Get-ChildItem -Path $DefinitionsFolder -Recurse -File -Filter "*.json"
$files = @()
$files += ($filesRaw  | Sort-Object -Property Name)
if ($files.Length -gt 0) {
    Write-Information "Number of documentation definition files = $($files.Length)"
}
else {
    Write-Error "No documentation definition files found!" -ErrorAction Stop
}

$processAllFiles = -not $Interactive -or $SuppressConfirmation -or $files.Length -eq 1
foreach ($file in $files) {

    $processThisFile = $processAllFiles
    if (-not $processAllFiles) {
        $Title = "Process documentation definition file '$($file.Name)'"
        $message = "Do you want to process the file?"

        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
            "Process the current file."
        $all = New-Object System.Management.Automation.Host.ChoiceDescription "&All", `
            "Process remaining files files in folder '$DefinitionsFolder'."
        $skip = New-Object System.Management.Automation.Host.ChoiceDescription "&Skip", `
            "Skip processing this file."
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $skip, $all)
        $result = $Host.UI.PromptForChoice($Title, $message, $options, 0)
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
            $PacEnvironment = $null
            foreach ($documentPolicySetEntry in $documentPolicySets) {
                $PacEnvironmentSelector = $documentPolicySetEntry.pacEnvironment
                if (-not $PacEnvironmentSelector) {
                    Write-Error "documentPolicySet entry does not specify pacEnvironment." -ErrorAction Stop
                }

                $FileNameStem = $documentPolicySetEntry.fileNameStem
                if (-not $FileNameStem) {
                    Write-Error "documentPolicySet entry does not specify fileNameStem." -ErrorAction Stop
                }

                $Title = $documentPolicySetEntry.title
                if (-not $Title) {
                    Write-Error "documentPolicySet entry does not specify title." -ErrorAction Stop
                }

                if ($documentPolicySetEntry.initiatives) {
                    Write-Error "Legacy field `"initiatives`" used, change to `"policySets`"." -ErrorAction Stop
                }
                $PolicySets = $documentPolicySetEntry.policySets
                if (-not $PolicySets -or $PolicySets.Count -eq 0) {
                    Write-Error "documentPolicySet entry does not specify required policySets array entry." -ErrorAction Stop
                }

                $itemArrayList = [System.Collections.ArrayList]::new()
                if ($null -ne $PolicySets -and $PolicySets.Count -gt 0) {
                    foreach ($PolicySet in $PolicySets) {
                        $itemEntry = @{
                            shortName    = $PolicySet.shortName
                            itemId       = $PolicySet.id
                            policySetId  = $PolicySet.id
                            assignmentId = $null
                        }
                        $null = $itemArrayList.Add($itemEntry)
                    }
                }
                else {
                    Write-Error "documentPolicySet entry does not specify an policySets array or policySets array is empty" -ErrorAction Stop
                }
                $ItemList = $itemArrayList.ToArray()

                $EnvironmentColumnsInCsv = $documentPolicySetEntry.environmentColumnsInCsv

                if (-not $CachedPolicyResourceDetails.ContainsKey($PacEnvironmentSelector)) {
                    if ($currentPacEnvironmentSelector -ne $PacEnvironmentSelector) {
                        $currentPacEnvironmentSelector = $PacEnvironmentSelector
                        $PacEnvironment = Switch-PacEnvironment `
                            -PacEnvironmentSelector $currentPacEnvironmentSelector `
                            -PacEnvironments $PacEnvironments `
                            -Interactive $Interactive

                    }
                }

                # Retrieve Policies and PolicySets for current pacEnvironment from cache or from Azure
                $PolicyResourceDetails = Get-PolicyResourceDetails `
                    -PacEnvironmentSelector $PacEnvironmentSelector `
                    -PacEnvironment $PacEnvironment `
                    -CachedPolicyResourceDetails $CachedPolicyResourceDetails
                $PolicySetDetails = $PolicyResourceDetails.policySets

                $FlatPolicyList = Convert-PolicySetsToFlatList `
                    -ItemList $ItemList `
                    -Details $PolicySetDetails

                # Print documentation
                Out-PolicySetsDocumentationToFile `
                    -OutputPath $OutputPath `
                    -FileNameStem $FileNameStem `
                    -WindowsNewLineCells:$WindowsNewLineCells `
                    -Title $Title `
                    -ItemList $ItemList `
                    -EnvironmentColumnsInCsv $EnvironmentColumnsInCsv `
                    -PolicySetDetails $PolicySetDetails `
                    -FlatPolicyList $FlatPolicyList
            }
        }

        # Process instructions to document Assignments
        if ($documentationSpec.documentAssignments) {
            $documentAssignments = $documentationSpec.documentAssignments
            $environmentCategories = $documentAssignments.environmentCategories

            # Process assignments for every environmentCategory specified
            [hashtable] $AssignmentsByEnvironment = @{}
            foreach ($environmentCategoryEntry in $environmentCategories) {
                if (-not $environmentCategoryEntry.pacEnvironment) {
                    Write-Error "JSON document does not contain the required 'pacEnvironment' element." -ErrorAction Stop
                }
                # Load pacEnvironment
                $PacEnvironmentSelector = $environmentCategoryEntry.pacEnvironment
                if ($currentPacEnvironmentSelector -ne $PacEnvironmentSelector) {
                    $currentPacEnvironmentSelector = $PacEnvironmentSelector
                    $PacEnvironment = Switch-PacEnvironment `
                        -PacEnvironmentSelector $currentPacEnvironmentSelector `
                        -PacEnvironments $PacEnvironments `
                        -Interactive $Interactive
                }

                # Retrieve Policies and PolicySets for current pacEnvironment from cache or from Azure
                $PolicyResourceDetails = Get-PolicyResourceDetails `
                    -PacEnvironmentSelector $currentPacEnvironmentSelector `
                    -PacEnvironment $PacEnvironment `
                    -CachedPolicyResourceDetails $CachedPolicyResourceDetails

                # Retrieve assignments and process information or retrieve from cache is assignment previously processed
                $AssignmentArray = $environmentCategoryEntry.representativeAssignments

                $ItemList, $AssignmentsDetails = Get-AssignmentsDetails `
                    -PacEnvironmentSelector $currentPacEnvironmentSelector `
                    -AssignmentArray $AssignmentArray `
                    -PolicyResourceDetails $PolicyResourceDetails `
                    -CachedAssignmentsDetails $CachedAssignmentsDetails

                # Flatten Policy lists in Assignments and reconcile the most restrictive effect for each Policy
                $FlatPolicyList = Convert-PolicySetsToFlatList `
                    -ItemList $ItemList `
                    -Details $AssignmentsDetails

                # Store results of processing and flattening for use in document generation
                $null = $AssignmentsByEnvironment.Add($environmentCategoryEntry.environmentCategory, @{
                        pacEnvironmentSelector = $currentPacEnvironmentSelector
                        scopes                 = $environmentCategoryEntry.scopes
                        itemList               = $ItemList
                        assignmentsDetails     = $AssignmentsDetails
                        flatPolicyList         = $FlatPolicyList
                    }
                )
            }

            # Build documents
            $DocumentationSpecifications = $documentAssignments.documentationSpecifications
            foreach ($DocumentationSpecification in $DocumentationSpecifications) {
                $documentationType = $DocumentationSpecification.type
                if ($null -ne $documentationType) {
                    Write-Information "Field documentationType ($($documentationType)) is deprecated"
                }
                Out-PolicyAssignmentDocumentationToFile `
                    -OutputPath $OutputPath `
                    -WindowsNewLineCells:$WindowsNewLineCells `
                    -DocumentationSpecification $DocumentationSpecification `
                    -AssignmentsByEnvironment $AssignmentsByEnvironment
            }
        }

    }
}
