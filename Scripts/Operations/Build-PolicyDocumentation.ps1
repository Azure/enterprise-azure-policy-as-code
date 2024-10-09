<#
.SYNOPSIS 
    Builds documentation from instructions in policyDocumentations folder reading the deployed Policy Resources from the EPAC environment.   

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

.PARAMETER IncludeManualPolicies
    Include Policies with effect Manual. Default: do not include Policies with effect Manual.

.EXAMPLE
    Build-PolicyDocumentation.ps1 -DefinitionsRootFolder "C:\PAC\Definitions" -OutputFolder "C:\PAC\Output" -Interactive
    Builds documentation from instructions in policyDocumentations folder reading the deployed Policy Resources from the EPAC environment.

.EXAMPLE
    Build-PolicyDocumentation.ps1 -Interactive
    Builds documentation from instructions in policyDocumentations folder reading the deployed Policy Resources from the EPAC environment. The script prompts for the PAC environment and uses the default definitions and output folders.

.EXAMPLE
    Build-PolicyDocumentation.ps1 -DefinitionsRootFolder "C:\PAC\Definitions" -OutputFolder "C:\PAC\Output" -Interactive -SuppressConfirmation
    Builds documentation from instructions in policyDocumentations folder reading the deployed Policy Resources from the EPAC environment. The script prompts for the PAC environment and uses the default definitions and output folders. It suppresses prompt for confirmation to delete existing file in interactive mode.

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
    [switch] $SuppressConfirmation,

    [Parameter(Mandatory = $false, HelpMessage = "Include Policies with effect Manual. Default: do not include Policies with effect Manual.")]
    [switch] $IncludeManualPolicies,

    [Parameter(Mandatory = $false, HelpMessage = "Include if using a PAT token for pushing to ADO Wiki.")]
    [string] $WikiClonePat,

    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $pacSelector
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
$outputPathServices = "$($globalSettings.outputFolder)/policy-documentation/services"
if (-not (Test-Path $outputPathServices)) {
    New-Item $outputPathServices -Force -ItemType directory
}
else {
    Get-ChildItem -Path $outputPathServices -File | Remove-Item
}

# Telemetry
if ($globalSettings.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    Submit-EPACTelemetry -Cuapid "pid-2dc29bae-2448-4d7f-b911-418421e83900" -DeploymentRootScope $pacEnvironment.deploymentRootScope
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
                $policyResourceDetails = Get-AzPolicyResourcesDetails `
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
                $flatPolicyList = Convert-PolicyResourcesDetailsToFlatList `
                    -ItemList $itemList `
                    -Details $policySetDetails

                # Print documentation
                Out-DocumentationForPolicySets `
                    -OutputPath $outputPath `
                    -WindowsNewLineCells:$WindowsNewLineCells `
                    -DocumentationSpecification $documentPolicySetEntry `
                    -ItemList $itemList `
                    -EnvironmentColumnsInCsv $environmentColumnsInCsv `
                    -PolicySetDetails $policySetDetails `
                    -FlatPolicyList $flatPolicyList `
                    -IncludeManualPolicies:$IncludeManualPolicies
            }
        }

        # Process instructions to document Assignments
        if ($documentationSpec.documentAssignments -and !$documentationSpec.documentAssignments.documentAllAssignments) {
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
                $policyResourceDetails = Get-AzPolicyResourcesDetails `
                    -PacEnvironmentSelector $currentPacEnvironmentSelector `
                    -PacEnvironment $pacEnvironment `
                    -CachedPolicyResourceDetails $cachedPolicyResourceDetails

                # Retrieve assignments and process information or retrieve from cache is assignment previously processed
                $assignmentArray = $environmentCategoryEntry.representativeAssignments

                $itemList, $assignmentsDetails = Get-PolicyAssignmentsDetails `
                    -PacEnvironmentSelector $currentPacEnvironmentSelector `
                    -AssignmentArray $assignmentArray `
                    -PolicyResourceDetails $policyResourceDetails `
                    -CachedAssignmentsDetails $cachedAssignmentsDetails

                # Flatten Policy lists in Assignments and reconcile the most restrictive effect for each Policy
                $flatPolicyList = Convert-PolicyResourcesDetailsToFlatList `
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
                Out-DocumentationForPolicyAssignments `
                    -OutputPath $outputPath `
                    -OutputPathServices $outputPathServices `
                    -WindowsNewLineCells:$WindowsNewLineCells `
                    -DocumentationSpecification $documentationSpecification `
                    -AssignmentsByEnvironment $assignmentsByEnvironment `
                    -IncludeManualPolicies:$IncludeManualPolicies `
                    -PacEnvironments $pacEnvironments
                # Out-DocumentationForPolicyAssignments `
                #     -OutputPath $outputPath `
                #     -WindowsNewLineCells:$true `
                #     -DocumentationSpecification $documentationSpecification `
                #     -AssignmentsByEnvironment $assignmentsByEnvironment
            }
        }

        if ($documentationSpec.documentAssignments -and $documentationSpec.documentAssignments.documentAllAssignments) {
            # Load pacEnvironments from policy documentations folder
            $pacEnvironmentSelector = $documentationSpec.documentAssignments.documentAllAssignments.pacEnvironment

            # Check to see if PacSelector was passed as a parameter
            if ($pacSelector) {
                $pacEnvironmentSelector = $pacSelector
                $pacSelectorDocumentAllAssignments = $documentationSpec.documentAssignments.documentAllAssignments | Where-Object { $_.pacEnvironment -eq "$pacSelector" }
                $documentationSpec.documentAssignments.documentAllAssignments = $pacSelectorDocumentAllAssignments

                if ($null -eq $documentationSpec.documentAssignments.documentAllAssignments) {
                    Write-Error "Provided PacSelector '$pacSelector' not found in $($file.Name)!" -ErrorAction Stop
                }
            }

            # Check to see if PacSelector was not passed as a parameter but there are multiple pacEnvironments configured within documentAllAssignments
            if ($pacEnvironmentSelector.count -gt 1 -and $pacSelector -eq "") {
                Write-Error "Multiple 'pacEnvironments' found in $($file.Name) - Please provide parameter -PacSelector to specify the documentation needed to be created" -ErrorAction Stop
            }
            $pacEnvironment = Switch-PacEnvironment `
                -PacEnvironmentSelector $pacEnvironmentSelector `
                -PacEnvironments $pacEnvironments `
                -Interactive $Interactive

            # Retrieve Policies and PolicySets for current pacEnvironment from cache or from Azure
            $policyResourceDetails = Get-AzPolicyResourcesDetails `
                -PacEnvironmentSelector $pacEnvironmentSelector `
                -PacEnvironment $pacEnvironment `
                -CachedPolicyResourceDetails $cachedPolicyResourceDetails `
                -CollectAllPolicies

            # Create artificial Environment Categories based on Assignment Scope
            $environmentCategories = @()
            foreach ($key in $policyResourceDetails.policyAssignments.keys) {
                if ($environmentCategories.environmentCategory -notContains ($policyResourceDetails.policyAssignments.$key.scopeDisplayName)) {
                    $environmentCategories += New-Object PSObject -Property @{
                        pacEnvironment            = $pacEnvironmentSelector
                        environmentCategory       = $policyResourceDetails.policyAssignments.$key.scopeDisplayName
                        scopes                    = @($policyResourceDetails.policyAssignments.$key.scopeType + ": " + $policyResourceDetails.policyAssignments.$key.scopeDisplayName)
                        representativeAssignments = @()
                        scopeid                   = $policyResourceDetails.policyAssignments.$key.scope
                    }
                }
            }
            
            # Assignment by environmentCategory
            foreach ($environment in $environmentCategories) {
                foreach ($key in $policyResourceDetails.policyAssignments.keys) {
                    # Validate the categories match to the populate with an assignment
                    if ($environment.environmentCategory -eq $policyResourceDetails.policyAssignments.$key.scopeDisplayName) {   
                        # Validate it is not in our list of skipAssignments
                        if ($key -notin $documentationSpec.documentAssignments.documentAllAssignments.skipPolicyAssignments) {
                            $defID = $policyResourceDetails.policyAssignments.$key.properties.policyDefinitionId
                            # Validate it is not in our list of skipPolicyDefinitions
                            if ($defID -notin $documentationSpec.documentAssignments.documentAllAssignments.skipPolicyDefinitions) {
                                $suffix = [guid]::NewGuid().Guid.split("-")[0]
                                $environment.representativeAssignments += New-Object PSObject -Property @{
                                    shortName = $policyResourceDetails.policyAssignments.$key.name + "_" + $suffix
                                    id        = $policyResourceDetails.policyAssignments.$key.id
                                }
                            }
                        }
                    }
                }
            }

            # Set overrideEnvironmentCategory to false if does not exist
            if ($null -eq $documentationSpec.documentAssignments.documentAllAssignments.overrideEnvironmentCategory) {
                $overrideEnvironmentCategory = ""
            }
            else {
                $overrideEnvironmentCategory = $documentationSpec.documentAssignments.documentAllAssignments.overrideEnvironmentCategory 
            }

            # Update overrideEnvironmentCategory where applicable
            if (!$overrideEnvironmentCategory -eq "") {
                foreach ($environment in $environmentCategories) {
                    foreach ($category in $overrideEnvironmentCategory.PSObject.Properties) {
                        if ($environment.scopeid -in $category.Value) {
                            $environment.environmentCategory = $category.Name
                        }
                    }
                }
                $tempEnvironmentCategory = @()
                foreach ($envCategory in $environmentCategories) {
                    if ($envCategory.environmentCategory -notin $tempEnvironmentCategory.environmentCategory) {
                        $tempEnvironmentCategory += New-Object PSObject -Property @{
                            pacEnvironment            = $envCategory.pacEnvironment
                            environmentCategory       = $envCategory.environmentCategory
                            scopes                    = $envCategory.scopes
                            representativeAssignments = $envCategory.representativeAssignments
                            scopeid                   = $envCategory.scopeid
                        }
                    }
                    else {
                        $tempEnvironmentCategory | Where-Object { $_.environmentCategory -eq $envCategory.environmentCategory } | ForEach-Object { $_.scopes += $envCategory.scopes }
                        $tempEnvironmentCategory | Where-Object { $_.environmentCategory -eq $envCategory.environmentCategory } | ForEach-Object { $_.representativeAssignments += $envCategory.representativeAssignments }
                        $tempEnvironmentCategory | Where-Object { $_.environmentCategory -eq $envCategory.environmentCategory } | ForEach-Object { $_.scopeid = "Multiple" }
                    }
                }

                $environmentCategories = $tempEnvironmentCategory
            }

            # Logic to move Tenant Root group to the first entry / column on Markdown
            $tenantRootCategory = $environmentCategories | Where-Object { $_.environmentCategory -eq "Tenant Root Group" }
            if ($null -ne $tenantRootCategory) {
                $environmentCategories = $environmentCategories | Where-Object { $_.environmentCategory -ne "Tenant Root Group" }
                $environmentCategories = , $tenantRootCategory + $environmentCategories
            }

            $documentAssignments = $documentationSpec.documentAssignments
            # Check if the member already exists
            if ($documentAssignments | Get-Member -Name "environmentCategories" -MemberType NoteProperty) {
                $documentAssignments.environmentCategories = $environmentCategories
            }
            else {
                $documentAssignments | Add-Member -MemberType NoteProperty -Name "environmentCategories" -Value $environmentCategories
            }

            $envCategoriesArray = @()
            foreach ($category in $environmentCategories.environmentCategory) {
                $envCategoriesArray += $category
            }

            $tempDocumentationSpecifications = @()
            $tempDocumentationSpecifications += New-Object PSObject -Property @{
                fileNameStem               = $documentAssignments.documentationSpecifications.fileNameStem
                environmentCategories      = $envCategoriesArray
                title                      = $documentAssignments.documentationSpecifications.title
                markdownAdoWiki            = $documentAssignments.documentationSpecifications.markdownAdoWiki
                markdownAdoWikiConfig      = if ($null -ne $documentAssignments.documentationSpecifications.markdownAdoWikiConfig) { $documentAssignments.documentationSpecifications.markdownAdoWikiConfig }else { $null }
                markdownMaxParameterLength = if ($null -ne $documentAssignments.documentationSpecifications.markdownMaxParameterLength) { $documentAssignments.documentationSpecifications.markdownMaxParameterLength }else { $null }
            }

            $documentAssignments.documentationSpecifications = $tempDocumentationSpecifications

            [hashtable] $assignmentsByEnvironment = @{}
            foreach ($environmentCategoryEntry in $environmentCategories) {
                if (-not $environmentCategoryEntry.pacEnvironment) {
                    Write-Error "JSON document does not contain the required 'pacEnvironment' element." -ErrorAction Stop
                }

                # Retrieve assignments and process information or retrieve from cache is assignment previously processed
                $assignmentArray = $environmentCategoryEntry.representativeAssignments

                $itemList, $assignmentsDetails = Get-PolicyAssignmentsDetails `
                    -PacEnvironmentSelector $currentPacEnvironmentSelector `
                    -AssignmentArray $assignmentArray `
                    -PolicyResourceDetails $policyResourceDetails `
                    -CachedAssignmentsDetails $cachedAssignmentsDetails

                # Flatten Policy lists in Assignments and reconcile the most restrictive effect for each Policy
                $flatPolicyList = Convert-PolicyResourcesDetailsToFlatList `
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
                # Check to see if naming contains prefix for file name
                if ($documentationSpec.documentAssignments.documentAllAssignments.fileNameStemPrefix) {
                    $documentationSpecification.fileNameStem = $documentationSpec.documentAssignments.documentAllAssignments.fileNameStemPrefix + "-" + $documentationSpecification.fileNameStem
                }

                $documentationType = $documentationSpecification.type
                if ($null -ne $documentationType) {
                    Write-Information "Field documentationType ($($documentationType)) is deprecated"
                }
                Out-DocumentationForPolicyAssignments `
                    -OutputPath $outputPath `
                    -OutputPathServices $outputPathServices `
                    -WindowsNewLineCells:$WindowsNewLineCells `
                    -DocumentationSpecification $documentationSpecification `
                    -AssignmentsByEnvironment $assignmentsByEnvironment `
                    -IncludeManualPolicies:$IncludeManualPolicies `
                    -PacEnvironments $pacEnvironments `
                    -WikiClonePat $WikiClonePat
            }
        }
    }
}
