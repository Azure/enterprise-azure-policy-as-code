<#
.SYNOPSIS
Generates policy documentation source files based on provided parameters and schema.

.DESCRIPTION
The New-PolicyDocumentationSourceFiles function generates policy documentation source files using the current defined schema online along with these inputs. It processes policy assignments and creates a new documentation template with assignment information that can be used to generate documentation for all Assignments, and supporting Definitions, specified in the Definitions folder.

.PARAMETER PacSelector
Specifies the PAC environment selector. This parameter is mandatory.

.PARAMETER OutputPath
Specifies the output path for the generated documentation files. The default value is "./Output".

.PARAMETER DefinitionsPath
Specifies the path to the definitions. The default value is "./Definitions".

.PARAMETER EnvironmentGroups
Specifies the environment groups as a hashtable, and can be used to override the Management Group based categories by specifying a list of k/v pairs that follow this format: ManagementGroupID: EnvironmentGroup. This will populate the environmentOverrides property. The default value is an empty hashtable.

.PARAMETER MaxParameterLength
Specifies the maximum length of parameters for Assignments in the documentation. The default value is 42.

.PARAMETER ReportTitle
Specifies the title of the report, and is an arbitrary value. The default value is "Azure Policy Effects".

.PARAMETER FileNameStem
Specifies the stem for the file name, and is an arbitrary value that needs to conform to the naming rules of the local filesystem. The default value is "PrimaryTenant".

.PARAMETER IncludeComplianceGroupNames
Includes compliance group names as headers in the documentation if specified.

.PARAMETER NoEmbeddedHtml
Excludes embedded HTML in the documentation if specified. This is appropriate for wikis that do not support embedded HTML, such as SharePoint.

.PARAMETER AddToc
Adds a table of contents to the Markdown documentation if specified.

.PARAMETER AdoOrganization
Specifies the Azure DevOps organization. This parameter is mandatory if any ADO parameters are set.

.PARAMETER AdoProject
Specifies the Azure DevOps project. This parameter is mandatory if any ADO parameters are set.

.PARAMETER AdoWiki
Specifies the Azure DevOps wiki. This parameter is mandatory if any ADO parameters are set.

.EXAMPLE
New-PolicyDocumentationSourceFiles -PacSelector "Production" -OutputPath "./Output" -DefinitionsPath "./Definitions" -EnvironmentGroups @{ "Group1" = "Location1" } -MaxParameterLength 50 -ReportTitle "Policy Report" -FileNameStem "tenant01" -IncludeComplianceGroupNames -NoEmbeddedHtml -AddToc -AdoOrganization "MyOrg" -AdoProject "MyProject" -AdoWiki "MyWiki"

#>
function New-HydrationPolicyDocumentationSourceFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Specifies the PAC environment selector. This parameter is mandatory.")]
        [string]
        $PacEnvironmentSelector,
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the output path for the generated documentation files. The default value is './Output'.")]
        [string]
        $OutputPath = "./Output",
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the path to the definitions. The default value is './Definitions'.")]
        [string]
        $DefinitionsPath = "./Definitions",
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the environment groups as a hashtable. This will populate the environmentOverrides property. The default value is an empty hashtable.")]
        [hashtable]
        $EnvironmentGroups = @{},
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the maximum length of parameters for Assignments in the documentation. The default value is 42.")]
        [int]
        $MaxParameterLength = 42,
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the title of the report. The default value is 'Azure Policy Effects'.")]
        [string]
        $ReportTitle = "Azure Policy Effects",
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the stem for the file name. The default value is 'PrimaryTenant'.")]
        [string]
        $FileNameStem = "PrimaryTenant",
        [Parameter(Mandatory = $false, HelpMessage = "Includes compliance group names as headers in the documentation if specified.")]
        [switch]
        $IncludeComplianceGroupNames,
        [Parameter(Mandatory = $false, HelpMessage = "Excludes embedded HTML in the documentation if specified. This is appropriate for wikis that do not support embedded HTML, such as SharePoint.")]
        [switch]
        $NoEmbeddedHtml,
        [Parameter(Mandatory = $false, HelpMessage = "Adds a table of contents to the Markdown documentation if specified.")]
        [switch]
        $AddToc,
        [Parameter(Mandatory = $false, ParameterSetName = 'AdoSet', HelpMessage = "Specifies the Azure DevOps organization. This parameter is mandatory if any ADO parameters are set.")]
        [string]
        $AdoOrganization,
        [Parameter(Mandatory = $false, ParameterSetName = 'AdoSet', HelpMessage = "Specifies the Azure DevOps project. This parameter is mandatory if any ADO parameters are set.")]
        [string]
        $AdoProject,
        [Parameter(Mandatory = $false, ParameterSetName = 'AdoSet', HelpMessage = "Specifies the Azure DevOps wiki. This parameter is mandatory if any ADO parameters are set.")]
        [string]
        $AdoWiki
    )
    $InformationPreference = "Continue"
    $policySets = @()
    $JsonSchemaUri = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-documentation-schema.json"
    $paths = @{
        policyAssignmentsPath = $(Join-Path $DefinitionsPath policyAssignments)
        outputPath            = $(Join-Path $OutputPath (Get-Date -Format "yyyy-MM-dd") policyDocumentations)
    }
    foreach ($path in $paths.Values) {
        if (!(Test-Path -Path $path)) {
            $null = New-Item -Path $path -ItemType Directory -Force
        }
    }
    $documentationObject = New-SchemaJsonTemplate  -JsonSchemaUri $JsonSchemaUri -Output $OutputPath # -Definitions $DefinitionsPath
    $documentationHashtable = $documentationObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -AsHashtable

    Write-Information "Gathering Assignment Information..."
    $fileList = Get-ChildItem -Path $paths.policyAssignmentsPath -Recurse -File -Include "*.json", "*.jsonc"

    Write-Information "Updating documentAssignments\documentAllAssignments section in the template with assignment information..."
    $documentationHashtable.documentAssignments.documentAllAssignments[0].pacEnvironment = $PacEnvironmentSelector
    if ($documentationHashtable.documentAssignments.documentAllAssignments[0].contains("enabled")) {
        $documentationHashtable.documentAssignments.documentAllAssignments[0].Remove("enabled")
    }
    $documentationHashtable.documentAssignments.documentAllAssignments[0].overrideEnvironmentCategory = @{}
    if ($EnvironmentGroups.Keys.count -gt 0) {
        # Set overrides
        Write-Information "Applying Override Environment Categories..."
        $groupList = $EnvironmentGroups.GetEnumerator() | Select-Object -ExpandProperty Value -Unique
        foreach ($group in $groupList) {
            $groupContentList = @()
            foreach ($managementGroup in $EnvironmentGroups.keys) {
                if ($EnvironmentGroups[$managementGroup] -eq $group) {
                    $groupContentList += $managementGroup
                }
            }
            $documentationHashtable.documentAssignments.documentAllAssignments[0].overrideEnvironmentCategory.Add($group, $groupContentList)
        }
    }
    Write-Information "Updating documentAssignments\documentationSpecifications section in the template with assignment information..."
    $documentationHashtable.documentAssignments.documentationSpecifications[0].fileNameStem = $FileNameStem
    $documentationHashtable.documentAssignments.documentationSpecifications[0].environmentCategories = @() # Not used in document all option as it is overridden
    $documentationHashtable.documentAssignments.documentationSpecifications[0].title = $ReportTitle
    $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownIncludeComplianceGroupNames = $IncludeComplianceGroupNames
    if ($SuppressParameterSection) {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownSuppressParameterSection = $true
    }
    else {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownSuppressParameterSection = $false
    }
    if ($IncludeComplianceGroupNames) {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownIncludeComplianceGroupNames = $true
    }
    else {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownIncludeComplianceGroupNames = $false
    }
    if ($NoEmbeddedHtml) {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownNoEmbeddedHtml = $true
    }
    else {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownNoEmbeddedHtml = $false
    }
    if ($AddToc) {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownAddToc = $true
    }
    else {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownAddToc = $false
    }

    $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownMaxParameterLength = $MaxParameterLength
    if ($AdoProject -and $AdoOrganization -and $AdoWiki) {
        $documentationHashtable.documentAssignments.documentationSpecifications[0].markdownAdoWiki = $true
        $documentationHashtable.documentAssignments.documentationSpecifications[0].add("markdownAdoWikiConfig", `
            @{
                adoOrganization = $AdoOrganization
                adoProject      = $AdoProject
                adoWiki         = $AdoWiki
            }
        )
    }
    else {
        Write-Debug "    No ADO information provided. Skipping ADO integration."
    }

    Write-Information "Updating documentPolicySets section in the template with assignment information..."
    $documentationHashtable.documentPolicySets[0].pacEnvironment = $PacEnvironmentSelector
    if ($AdoProject -and $AdoOrganization -and $AdoWiki) {
        $documentationHashtable.documentPolicySets[0].markdownAdoWiki = $true
    }
    else {
        Write-Debug "    No ADO information provided. Skipping ADO integration."
    }

    $documentationHashtable.documentPolicySets[0].fileNameStem = $FileNameStem
    $documentationHashtable.documentPolicySets[0].environmentCategories = @() 
    $documentationHashtable.documentPolicySets[0].environmentColumnsInCsv = @() 

    $documentationHashtable.documentPolicySets[0].title = $ReportTitle
    $documentationHashtable.documentPolicySets[0].markdownIncludeComplianceGroupNames = $IncludeComplianceGroupNames
    if ($SuppressParameterSection) {
        $documentationHashtable.documentPolicySets[0].markdownSuppressParameterSection = $true
    }
    else {
        $documentationHashtable.documentPolicySets[0].markdownSuppressParameterSection = $false
    }
    if ($IncludeComplianceGroupNames) {
        $documentationHashtable.documentPolicySets[0].markdownIncludeComplianceGroupNames = $true
    }
    else {
        $documentationHashtable.documentPolicySets[0].markdownIncludeComplianceGroupNames = $false
    }
    if ($NoEmbeddedHtml) {
        $documentationHashtable.documentPolicySets[0].markdownNoEmbeddedHtml = $true
    }
    else {
        $documentationHashtable.documentPolicySets[0].markdownNoEmbeddedHtml = $false
    }
    if ($AddToc) {
        $documentationHashtable.documentPolicySets[0].markdownAddToc = $true
    }
    else {
        $documentationHashtable.documentPolicySets[0].markdownAddToc = $false
    }

    $documentationHashtable.documentPolicySets[0].markdownMaxParameterLength = $MaxParameterLength

    $planFile = Join-Path $OutputPath $( -join ('plans-', $PacEnvironmentSelector)) 'policy-plan.json'

    Build-HydrationDeploymentPlans -PacEnvironmentSelector $PacEnvironmentSelector `
        -DefinitionsRootFolder:$DefinitionsPath `
        -OutputFolder:$OutputPath `
        -FullExportForDocumentationFile
    $planContent = Get-DeploymentPlan -PlanFile $planFile
    $assignments = $planContent.assignments.new | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
    $policySetDefinitionList = @()
    foreach ($aplan in $assignments.keys) {
        $scopeName = $assignments.$aplan.scope.split("/")[-1]
        if ($assignments.$aplan.policyDefinitionId -like "*policySetDefinitions*" -and $assignments.$aplan.policyDefinitionId -like "*$scopeName*") {
            $policySetDefinitionList += @{
                name      = $assignments.$aplan.policyDefinitionId.split("/")[-1]
                shortName = $assignments.$aplan.id.split("/")[-1] 
            }
        }
        elseif ($assignments.$aplan.policyDefinitionId -like "*policySetDefinitions*" -and !($assignments.$aplan.policyDefinitionId -like "*$scopeName*")) {
            $policySetDefinitionList += @{
                id        = $assignments.$aplan.policyDefinitionId
                shortName = $assignments.$aplan.id.split("/")[-1] 
            }
        }
    }
    Write-Information "PolicySet List Count: $($policySetDefinitionList.count)"

    if ($policySetDefinitionList.count -gt 0) {
        $documentationHashtable.documentPolicySets[0].policySets = $policySetDefinitionList | Sort-Object -Property @{Expression = { $_.name + $_.shortName + $_.id } } -Unique
    }
    else {
        Write-Information "No PolicySets assigned. Assignments will be documented without PolicySets."
        continue
    }
    $fullOutputPath = Join-Path $paths.outputPath "$FileNameStem.jsonc"
    Write-Information "Outputting new documentation file to $fullOutputPath"
    $documentationHashtable | ConvertTo-Json -Depth 100 | Out-File -FilePath $fullOutputPath -Force
}