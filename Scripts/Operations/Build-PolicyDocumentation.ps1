<#
.SYNOPSIS 
    Builds documentation from instructions in policyDocumentations folder reading the delployed Policy Resources from the EPAC envioronment.   

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFolder
    Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

.PARAMETER WindowsNewLineCells
    Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell

.PARAMETER Interactive
    Set to false if used non-interactive

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
    https://azure.github.io/enterprise-azure-policy-as-code/#deployment-scripts
    https://azure.github.io/enterprise-azure-policy-as-code/operational-scripts/#build-policyassignmentdocumentationps1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell")]
    [switch] $WindowsNewLineCells,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Suppresses prompt for confirmation of each file in interactive mode")]
    [switch] $SuppressConfirmation
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

#region Initialize

$InformationPreference = 'Continue'
$globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder
$definitionsFolder = $globalSettings.policyDocumentationsFolder
$pacEnvironments = $globalSettings.pacEnvironments
$outputPath = "$($globalSettings.outputFolder)/policy-documentation"
if (-not (Test-Path $outputPath)) {
    New-Item $outputPath -Force -ItemType directory
}

# Telemetry
if ($globalSettings.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("pid-2dc29bae-2448-4d7f-b911-418421e83900") 
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

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

$processAllFiles = -not $Interactive -or $SuppressConfirmation -or $files.Length -eq 1
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
        try {
            $documentationSpec = $json | ConvertFrom-Json
        }
        catch {
            Write-Error "Assignment JSON file '$($file.Name)' is not valid." -ErrorAction Stop
        }
        
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
                $environmentColumnsInCsv = $documentPolicySetEntry.environmentColumnsInCsv

                # Load pacEnvironment if not already loaded
                if (-not $cachedPolicyResourceDetails.ContainsKey($pacEnvironmentSelector)) {
                    if ($currentPacEnvironmentSelector -ne $pacEnvironmentSelector) {
                        $currentPacEnvironmentSelector = $pacEnvironmentSelector
                        $pacEnvironment = Switch-PacEnvironment `
                            -PacEnvironmentSelector $currentPacEnvironmentSelector `
                            -PacEnvironments $pacEnvironments `
                            -Interactive $Interactive

                    }
                }

                # Retrieve Policies and PolicySets for current pacEnvironment from cache or from Azure
                $policyResourceDetails = Get-PolicyResourceDetails `
                    -PacEnvironmentSelector $pacEnvironmentSelector `
                    -PacEnvironment $pacEnvironment `
                    -CachedPolicyResourceDetails $cachedPolicyResourceDetails
                $policySetDetails = $policyResourceDetails.policySets

                # Calculate itemList
                $itemArrayList = [System.Collections.ArrayList]::new()
                if ($null -ne $policySets -and $policySets.Count -gt 0) {
                    foreach ($policySet in $policySets) {
                        $id = $policySet.id
                        $name = $policySet.name
                        if ($null -eq $id -xor $null -eq $name) {
                            $id = Confirm-PolicySetDefinitionUsedExists `
                                -Id $id `
                                -Name $name `
                                -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                -AllPolicySetDefinitions $policySetDetails
                        }
                        else {
                            Write-Error "documentPolicySet:policySet entry must contain a name or an id field and not both" -ErrorAction Stop
                        }
                        $itemEntry = @{
                            shortName    = $policySet.shortName
                            itemId       = $id
                            policySetId  = $id
                            assignmentId = $null
                        }
                        $null = $itemArrayList.Add($itemEntry)
                    }
                }
                else {
                    Write-Error "documentPolicySet entry does not specify a policySets array or policySets array is empty" -ErrorAction Stop
                }
                $itemList = $itemArrayList.ToArray()

                # flatten structure and reconcile most restrictive effect for each policy
                $flatPolicyList = Convert-PolicySetsToFlatList `
                    -ItemList $itemList `
                    -Details $policySetDetails

                # Print documentation
                Out-PolicySetsDocumentationToFile `
                    -OutputPath $outputPath `
                    -FileNameStem $fileNameStem `
                    -WindowsNewLineCells:$WindowsNewLineCells `
                    -Title $title `
                    -ItemList $itemList `
                    -EnvironmentColumnsInCsv $environmentColumnsInCsv `
                    -PolicySetDetails $policySetDetails `
                    -FlatPolicyList $flatPolicyList
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
                        -PacEnvironmentSelector $currentPacEnvironmentSelector `
                        -PacEnvironments $pacEnvironments `
                        -Interactive $Interactive
                }

                # Retrieve Policies and PolicySets for current pacEnvironment from cache or from Azure
                $policyResourceDetails = Get-PolicyResourceDetails `
                    -PacEnvironmentSelector $currentPacEnvironmentSelector `
                    -PacEnvironment $pacEnvironment `
                    -CachedPolicyResourceDetails $cachedPolicyResourceDetails

                # Retrieve assignments and process information or retrieve from cache is assignment previously processed
                $assignmentArray = $environmentCategoryEntry.representativeAssignments

                $itemList, $assignmentsDetails = Get-AssignmentsDetails `
                    -PacEnvironmentSelector $currentPacEnvironmentSelector `
                    -AssignmentArray $assignmentArray `
                    -PolicyResourceDetails $policyResourceDetails `
                    -CachedAssignmentsDetails $cachedAssignmentsDetails

                # Flatten Policy lists in Assignments and reconcile the most restrictive effect for each Policy
                $flatPolicyList = Convert-PolicySetsToFlatList `
                    -ItemList $itemList `
                    -Details $assignmentsDetails

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
                    -OutputPath $outputPath `
                    -WindowsNewLineCells:$WindowsNewLineCells `
                    -DocumentationSpecification $documentationSpecification `
                    -AssignmentsByEnvironment $assignmentsByEnvironment
                # Out-PolicyAssignmentDocumentationToFile `
                #     -OutputPath $outputPath `
                #     -WindowsNewLineCells:$true `
                #     -DocumentationSpecification $documentationSpecification `
                #     -AssignmentsByEnvironment $assignmentsByEnvironment
            }
        }

    }
}
