<#
.SYNOPSIS
Exports Azure Policy resources in EPAC format or raw format.

.DESCRIPTION
Exports Azure Policy resources in EPAC format or raw format. It has 4 operating modes - see -Mode parameter for details.
It also generates documentaion for the exported resources (can be suppressed with -SuppressDocumentation).
To just generate EPAC formatted Definitions without generating documentaion files, use -supressEpacOutput.

.PARAMETER DefinitionsRootFolder
Definitions folder path. Defaults to environment variable $env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFolder
Output Folder. Defaults to environment variable $env:PAC_OUTPUT_FOLDER or './Outputs'.

.PARAMETER Interactive
Set to false if used non-interactive. Defaults to $true.

.PARAMETER IncludeChildScopes
Switch parameter to include Policies and Policy Sets definitions in child scopes

.PARAMETER IncludeAutoAssigned
Switch parameter to include Assignments auto-assigned by Defender for Cloud

.PARAMETER ExemptionFiles
Create Exemption files (none=suppress, csv=as a csv file, json=as a json or jsonc file). Defaults to 'csv'.

.PARAMETER FileExtension
File extension type for the output files. Defaults to '.jsonc'.

.PARAMETER Mode
Operating mode:
    a) 'export' exports EPAC environments in EPAC format, should be used with -Interactive $true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.
    b) 'collectRawFile' exports the raw data only; Often used with 'inputPacSelector' when running non-interactive in a multi-tenant scenario to collect the raw data once per tenant into a file named after the EPAC environment
    c) 'exportFromRawFiles' reads the files generated with one or more runs of b) and outputs the files the same as normal 'export'.
    d) 'exportRawToPipeline' exports EPAC environments in EPAC format, should be used with -Interactive $true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.

.PARAMETER InputPacSelector
Limits the collection to one EPAC environment, useful for non-interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'.
The default is '*' which will execute all EPAC-Environments.

.PARAMETER SuppressDocumentation
Suppress documentation generation.

.PARAMETER SuppressEpacOutput
Suppress output generation in EPAC format.

.EXAMPLE
Export-AzPolicyResources -DefinitionsRootFolder ./Definitions -OutputFolder ./Outputs -Interactive $true -IncludeChildScopes -IncludeAutoAssigned -ExemptionFiles csv -FileExtension jsonc -Mode export -InputPacSelector '*'

.EXAMPLE
Export-AzPolicyResources -DefinitionsRootFolder ./Definitions -OutputFolder ./Outputs -Interactive $true -IncludeChildScopes -IncludeAutoAssigned -ExemptionFiles csv -FileExtension jsonc -Mode export -InputPacSelector 'EPAC-Environment-1'

.LINK
https://azure.github.io/enterprise-azure-policy-as-code/extract-existing-policy-resources
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Switch to include Policies and Policy Sets definitions in child scopes")]
    [switch] $IncludeChildScopes,

    [Parameter(Mandatory = $false, HelpMessage = "Switch parameter to include Assignments auto-assigned by Defender for Cloud")]
    [switch] $IncludeAutoAssigned,

    [ValidateSet("none", "csv", "json")]
    [Parameter(Mandatory = $false, HelpMessage = "Create Exemption files (none=suppress, csv=as a csv file, json=as a json or jsonc file). Defaults to 'csv'.")]
    [string] $ExemptionFiles = "csv",

    [ValidateSet("json", "jsonc")]
    [Parameter(Mandatory = $false, HelpMessage = "File extension type for the output files. Defaults to '.jsonc'.")]
    [string] $FileExtension = "jsonc",

    [ValidateSet("export", "collectRawFile", 'exportFromRawFiles', "exportRawToPipeline")]
    [Parameter(Mandatory = $false, HelpMessage = "
        Operating mode:
        a) 'export' exports EPAC environments in EPAC format, should be used with -Interactive `$true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.
        b) 'collectRawFile' exports the raw data only; Often used with 'inputPacSelector' when running non-interactive in a multi-tenant scenario to collect the raw data once per tenant into a file named after the EPAC environment
        c) 'exportFromRawFiles' reads the files generated with one or more runs of b) and outputs the files the same as normal 'export'.
        d) 'exportRawToPipeline' exports EPAC environments in EPAC format, should be used with -Interactive `$true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.
    ")]
    [string] $Mode = 'export',
    # [string] $Mode = 'collectRawFile',
    # [string] $Mode = 'exportFromRawFiles',
    # [string] $Mode = 'exportRawToPipeline',

    [Parameter(Mandatory = $false, HelpMessage = "
        Limits the collection to one EPAC environment, useful for non-interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'.
        The default is '*' which will execute all EPAC-Environments.
    ")]
    [string] $InputPacSelector = '*',

    [Parameter(Mandatory = $false, HelpMessage = "Suppress documentation generation")]
    [switch] $SuppressDocumentation,

    [Parameter(Mandatory = $false, HelpMessage = "Suppress output generation in EPAC format")]
    [switch] $SuppressEpacOutput
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

#region Initialize

$InformationPreference = "Continue"
$globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -InputFolder $inputFolder
$pacEnvironments = $globalSettings.pacEnvironments
$OutputFolder = $globalSettings.outputFolder
$rawFolder = "$($OutputFolder)/RawDefinitions"
$definitionsFolder = "$($OutputFolder)/Definitions"
$policyDefinitionsFolder = "$definitionsFolder/policyDefinitions"
$policySetDefinitionsFolder = "$definitionsFolder/policySetDefinitions"
$policyAssignmentsFolder = "$definitionsFolder/policyAssignments"
$policyExemptionsFolder = "$definitionsFolder/policyExemptions"
$invalidChars = [IO.Path]::GetInvalidFileNameChars()
$invalidChars += ("[]()$".ToCharArray())
Write-Information "Mode: $Mode"
if ($Mode -eq 'export' -or $Mode -eq 'exportFromRawFiles') {
    if (Test-Path $definitionsFolder) {
        if ($Interactive) {
            Write-Information ""
            Remove-Item $definitionsFolder -Recurse -Confirm
            Write-Information ""
        }
        else {
            Remove-Item $definitionsFolder -Recurse
        }
    }

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Exporting Policy resources"
    Write-Information "==================================================================================================="
    Write-Information "WARNING! This script::"
    Write-Information "* Assumes Policies and Policy Sets with the same name define the same properties independent of scope and EPAC environment."
    Write-Information "* Ignores (default) Assignments auto-assigned by Security Center unless -IncludeAutoAssigned is used."
    Write-Information "==================================================================================================="
}
else {
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Collecting Policy resources (raw)"
    Write-Information "==================================================================================================="
}

$policyPropertiesByName = @{}
$policySetPropertiesByName = @{}
$definitionPropertiesByDefinitionKey = @{}
$assignmentsByPolicyDefinition = @{}

$propertyNames = @(
    "parameters",
    "overrides",
    "resourceSelectors",
    "enforcementMode",
    "nonComplianceMessages",
    "metadata",
    "additionalRoleAssignments",
    "assignmentNameEx", # name, displayName, description
    "identityEntry", # $null, userAssigned, location
    "notScopes",
    "scopes"
)

$policyResourcesByPacSelector = @{}

#endregion Initialize

if ($Mode -ne 'exportFromRawFiles') {

    #region retrieve Policy resources

    foreach ($pacEnvironment in $pacEnvironments.Values) {

        $pacSelector = $pacEnvironment.pacSelector

        if ($InputPacSelector -eq $pacSelector -or $InputPacSelector -eq '*') {
            $null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $Interactive

            $scopeTable = Get-AzScopeTree -PacEnvironment $pacEnvironment
            $skipExemptions = $ExemptionFiles -eq "none"
            $deployed = Get-AzPolicyResources -PacEnvironment $pacEnvironment -ScopeTable $scopeTable -SkipExemptions:$skipExemptions -CollectAllPolicies:$IncludeChildScopes

            $policyDefinitions = $deployed.policydefinitions.custom
            $policySetDefinitions = $deployed.policysetdefinitions.custom
            $policyAssignments = $deployed.policyassignments.all
            $policyExemptions = $deployed.policyExemptions.all

            $policyResources = @{
                policyDefinitions    = $policyDefinitions
                policySetDefinitions = $policySetDefinitions
                policyAssignments    = $policyAssignments
                policyExemptions     = $policyExemptions
            }
            $policyResourcesByPacSelector[$pacSelector] = $policyResources

            if ($Mode -eq 'collectRawFile') {
                # write file
                $fullPath = "$rawFolder/$pacSelector.json"
                $json = ConvertTo-Json $policyResources -Depth 100
                $null = New-Item $fullPath -Force -ItemType File -Value $json
            }
        }
    }

    if ($Mode -eq 'collectRawFile') {
        # exit; we-re done with this run
        return 0
    }
    elseif ($Mode -eq 'exportRawToPipeline') {
        # write to pipeline
        Write-Output $policyResourcesByPacSelector
        return 0
    }

    #endregion retrieve Policy resources

}
else {
    # read file and put in the data structure for the next section
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Reading raw Policy Resource files in folder '$rawFolder'"
    Write-Information "==================================================================================================="
    $rawFiles = @()
    $rawFiles += Get-ChildItem -Path $rawFolder -Recurse -File -Filter "*.json"
    if ($rawFiles.Length -gt 0) {
        Write-Information "Number of raw files = $($rawFiles.Length)"
    }
    else {
        Write-Error "No raw files found!" -ErrorAction Stop
    }

    foreach ($file in $rawFiles) {
        $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        if (!(Test-Json $Json)) {
            Write-Error "Raw file '$($file.FullName)' is not valid." -ErrorAction Stop
        }
        $policyResources = $Json | ConvertFrom-Json -Depth 100 -AsHashTable
        $currentPacSelector = $file.BaseName
        $policyResourcesByPacSelector[$currentPacSelector] = $policyResources
    }
}

foreach ($pacEnvironment in $pacEnvironments.Values) {

    $pacSelector = $pacEnvironment.pacSelector

    if (($InputPacSelector -eq $pacSelector -or $InputPacSelector -eq '*') -and $policyResourcesByPacSelector.ContainsKey($pacSelector)) {

        $policyResources = $policyResourcesByPacSelector.$pacSelector
        $policyDefinitions = $policyResources.policyDefinitions
        $policySetDefinitions = $policyResources.policySetDefinitions
        $policyAssignments = $policyResources.policyAssignments
        $policyExemptions = $policyResources.policyExemptions

        #region Policy definitions

        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Processing $($policyDefinitions.psbase.Count) Policies from EPAC environment '$pacSelector'"
        Write-Information "==================================================================================================="

        foreach ($policyDefinition in $policyDefinitions.Values) {
            $properties = Get-PolicyResourceProperties -PolicyResource $policyDefinition
            $metadata = Get-CustomMetadata $properties.metadata -Remove "pacOwnerId"
            $version = $properties.version
            $id = $policyDefinition.id
            $name = $policyDefinition.name
            # if ($null -eq $version) {
            #     if ($metadata.version) {
            #         $version = $metadata.version
            #     }
            #     else {
            #         $version = 1.0.0
            #     }
            # }

            $definition = [PSCustomObject]@{
                name       = $name
                properties = [PSCustomObject]@{
                    displayName = $properties.displayName
                    description = $properties.description
                    mode        = $properties.mode
                    metadata    = $metadata
                    version     = $version
                    parameters  = $properties.parameters
                    policyRule  = [PSCustomObject]@{
                        if   = $properties.policyRule.if
                        then = $properties.policyRule.then
                    }
                }
            }
            Out-PolicyDefinition `
                -Definition $definition `
                -Folder $policyDefinitionsFolder `
                -PolicyPropertiesByName $policyPropertiesByName `
                -InvalidChars $invalidChars `
                -Id $id `
                -FileExtension $FileExtension
        }

        # cache properties per definition key
        $definitions = $deployed.policydefinitions.all
        foreach ($id in $definitions.Keys) {
            $parts = Split-AzPolicyResourceId -Id $id
            $policyDefinitionKey = $parts.definitionKey
            $definition = $definitions.$id
            if (!($definitionPropertiesByDefinitionKey.ContainsKey($policyDefinitionKey))) {
                $definitionPropertiesByDefinitionKey[$policyDefinitionKey] = $definition.properties
            }
        }

        #endregion Policy definitions

        #region Policy Set definitions

        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Processing $($policySetDefinitions.psbase.Count) Policy Sets from EPAC environment '$pacSelector'"
        Write-Information "==================================================================================================="

        foreach ($policySetDefinition in $policySetDefinitions.Values) {
            $properties = Get-PolicyResourceProperties -PolicyResource $policySetDefinition
            $metadata = Get-CustomMetadata $properties.metadata -Remove "pacOwnerId"
            $version = $properties.version
            # if ($null -eq $version) {
            #     if ($metadata.version) {
            #         $version = $metadata.version
            #     }
            #     else {
            #         $version = 1.0.0
            #     }
            # }

            # Adjust policyDefinitions for EPAC
            $policyDefinitionsIn = Get-DeepClone $properties.policyDefinitions -AsHashTable
            $policyDefinitionsOut = [System.Collections.ArrayList]::new()
            foreach ($policyDefinitionIn in $policyDefinitionsIn) {
                $parts = Split-AzPolicyResourceId -Id $policyDefinitionIn.policyDefinitionId
                $policyDefinitionOut = $null
                if ($parts.scopeType -eq "builtin") {
                    $policyDefinitionOut = [PSCustomObject]@{
                        policyDefinitionReferenceId = $policyDefinitionIn.policyDefinitionReferenceId
                        policyDefinitionId          = $policyDefinitionIn.policyDefinitionId
                        parameters                  = $policyDefinitionIn.parameters
                    }
                }
                else {
                    $policyDefinitionOut = [PSCustomObject]@{
                        policyDefinitionReferenceId = $policyDefinitionIn.policyDefinitionReferenceId
                        policyDefinitionName        = $parts.name
                        parameters                  = $policyDefinitionIn.parameters
                    }
                }
                if ($policyDefinitionIn.definitionVersion) {
                    Add-Member -InputObject $policyDefinitionOut -TypeName "NoteProperty" -NotePropertyName "definitionVersion" -NotePropertyValue $policyDefinitionIn.definitionVersion
                }
                $groupNames = $policyDefinitionIn.groupNames
                if ($null -ne $groupNames -and $groupNames.Count -gt 0) {
                    Add-Member -InputObject $policyDefinitionOut -TypeName "NoteProperty" -NotePropertyName "groupNames" -NotePropertyValue $groupNames
                }
                $null = $policyDefinitionsOut.Add($policyDefinitionOut)
            }

            $definition = [PSCustomObject]@{
                name       = $policySetDefinition.name
                properties = [PSCustomObject]@{
                    displayName            = $properties.displayName
                    description            = $properties.description
                    metadata               = $metadata
                    version                = $version
                    parameters             = $properties.parameters
                    policyDefinitions      = $policyDefinitionsOut.ToArray()
                    policyDefinitionGroups = $properties.policyDefinitionGroups
                }
            }
            Out-PolicyDefinition `
                -Definition $definition `
                -Folder $policySetDefinitionsFolder `
                -PolicyPropertiesByName $policySetPropertiesByName `
                -InvalidChars $invalidChars `
                -Id $policySetDefinition.id `
                -FileExtension $FileExtension
        }

        # cache properties per definition key
        $definitions = $deployed.policysetdefinitions.all
        foreach ($id in $definitions.Keys) {
            $parts = Split-AzPolicyResourceId -Id $id
            $policyDefinitionKey = $parts.definitionKey
            $definition = $definitions.$id
            if (!($definitionPropertiesByDefinitionKey.ContainsKey($policyDefinitionKey))) {
                $definitionPropertiesByDefinitionKey[$policyDefinitionKey] = $definition.properties
            }
        }

        #endregion Policy Set definitions

        #region process Exemptions

        if (-not $skipExemptions) {
            Out-PolicyExemptions `
                -Exemptions $policyExemptions `
                -Assignments $policyAssignments `
                -PacEnvironment $pacEnvironment `
                -PolicyExemptionsFolder $policyExemptionsFolder `
                -OutputJson:($ExemptionFiles -eq "json") `
                -OutputCsv:($ExemptionFiles -eq "csv") `
                -ExemptionOutputType "active" `
                -FileExtension $FileExtension
        }

        #endregion process Exemptions

        #region Policy Assignments collate multiple entries by policyDefinitionId

        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Collating $($policyAssignments.psbase.Count) Policy Assignments from EPAC environment '$pacSelector'"
        Write-Information "==================================================================================================="

        foreach ($policyAssignment in $policyAssignments.Values) {
            $id = $policyAssignment.id
            if (!$IncludeAutoAssigned -and `
                (
                    $id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/ASC-*" `
                        -or $id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/SecurityCenterBuiltIn"
                )
            ) {
                Write-Warning "Do not process Security Center: $id"
            }
            else {
                $properties = Get-PolicyResourceProperties -PolicyResource $policyAssignment
                $rawMetadata = $properties.metadata
                $roles = @()
                if ($rawMetadata.roles) {
                    $roles = $rawMetadata.roles
                }
                $metadata = Get-CustomMetadata $properties.metadata -Remove "pacOwnerId, roles"

                $name = $policyAssignment.name
                $policyDefinitionId = $properties.policyDefinitionId
                $parts = Split-AzPolicyResourceId -Id $policyDefinitionId
                $policyDefinitionKey = $parts.definitionKey
                $enforcementMode = $properties.enforcementMode
                $displayName = $policyAssignment.name
                if ($null -ne $properties.displayName -and $properties.displayName -ne "") {
                    $displayName = $properties.displayName
                }
                $displayName = $properties.name
                if ($null -ne $properties.displayName -and $properties.displayName -ne "") {
                    $displayName = $properties.displayName
                }
                $description = ""
                if ($null -ne $properties.description) {
                    $description = $properties.description
                }
                $assignmentNameEx = @{
                    name        = $name
                    displayName = $displayName
                    description = $description
                }

                $scope = $policyAssignment.resourceIdParts.scope
                $notScopes = Remove-GlobalNotScopes `
                    -NotScopes $policyAssignment.notScopes `
                    -GlobalNotScopes $pacEnvironment.globalNotScopes
                if ($notScopes.Count -eq 0) {
                    $notScopes = $null
                }

                $additionalRoleAssignments = [System.Collections.ArrayList]::new()
                foreach ($role in $roles) {
                    if ($scope -ne $role.scope) {
                        $roleAssignment = @{
                            roleDefinitionId = $role.roleDefinitionId
                            scope            = $role.scope
                        }
                        $null = $additionalRoleAssignments.Add($roleAssignment)
                    }
                }

                $identityEntry = $null
                $identityType = $policyAssignment.identity.type
                $location = $policyAssignment.location
                if ($location -eq $pacEnvironment.managedIdentityLocation) {
                    $location = ""
                }
                if ($identityType -eq "UserAssigned") {
                    $userAssignedIdentities = $policyAssignment.identity.userAssignedIdentities
                    $identityProperty = $userAssignedIdentities.psobject.Properties
                    $identity = $identityProperty.Name
                    $identityEntry = @{
                        userAssigned = $identity
                        location     = $location
                    }
                }
                elseif ($identityType -eq "SystemAssigned") {
                    $identityEntry = @{
                        userAssigned = $null
                        location     = $location
                    }
                }

                $parameters = @{}
                if ($null -ne $properties.parameters -and $properties.parameters.psbase.Count -gt 0) {
                    $parametersClone = Get-DeepClone $properties.parameters -AsHashTable
                    foreach ($parameterName in $parametersClone.Keys) {
                        $parameterValue = $parametersClone.$parameterName
                        $parameters[$parameterName] = $parameterValue.value
                    }
                }
                $overrides = $properties.overrides
                $resourceSelectors = $properties.resourceSelectors

                $nonComplianceMessages = $null
                if ($properties.nonComplianceMessages -and $properties.nonComplianceMessages.Count -gt 0) {
                    $nonComplianceMessages = $properties.nonComplianceMessages
                }

                $perDefinition = $null

                $propertiesList = @{
                    parameters                = $parameters
                    overrides                 = $overrides
                    resourceSelectors         = $resourceSelectors
                    enforcementMode           = $enforcementMode
                    nonComplianceMessages     = $nonComplianceMessages
                    additionalRoleAssignments = $additionalRoleAssignments
                    assignmentNameEx          = $assignmentNameEx
                    metadata                  = $metadata
                    identityEntry             = $identityEntry
                    scopes                    = $scope
                    notScopes                 = $notScopes
                }

                $perDefinition = $null
                if (-not $assignmentsByPolicyDefinition.ContainsKey($policyDefinitionKey)) {
                    $definitionProperties = $definitionPropertiesByDefinitionKey.$policyDefinitionKey
                    $perDefinition = @{
                        parent          = $null
                        clusters        = @{}
                        children        = [System.Collections.ArrayList]::new()
                        definitionEntry = @{
                            definitionKey = $policyDefinitionKey
                            id            = $parts.id
                            name          = $parts.name
                            displayName   = $definitionProperties.displayName
                            scope         = $parts.scope
                            scopeType     = $parts.scopeType
                            kind          = $parts.kind
                            isBuiltin     = $parts.scopeType -eq "builtin"
                        }
                    }
                    $null = $assignmentsByPolicyDefinition.Add($policyDefinitionKey, $perDefinition)
                }
                else {
                    $perDefinition = $assignmentsByPolicyDefinition.$policyDefinitionKey
                }
                Set-ExportNode -ParentNode $perDefinition -PacSelector $pacSelector -PropertyNames $propertyNames -PropertiesList $propertiesList -CurrentIndex 0

            }
        }
        #endregion Policy Assignments collate multiple entries by policyDefinitionId

    }
}

#region prep tree for collapsing nodes

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Optimizing $($assignmentsByPolicyDefinition.psbase.Count) Policy Assignment trees"
Write-Information "==================================================================================================="

# $fullPath = "$policyAssignmentsFolder/tree-raw.$FileExtension"
# $object = Get-HashtableWithPropertyNamesRemoved -Object $assignmentsByPolicyDefinition -PropertyNames "parent", "clusters"
# $json = ConvertTo-Json $object -Depth 100
# $null = New-Item $fullPath -Force -ItemType File -Value $json

foreach ($policyDefinitionKey in $assignmentsByPolicyDefinition.Keys) {
    $perDefinition = $assignmentsByPolicyDefinition.$policyDefinitionKey
    foreach ($child in $perDefinition.children) {
        Set-ExportNodeAncestors `
            -CurrentNode $child `
            -PropertyNames $propertyNames `
            -CurrentIndex 0
    }
}

# $fullPath = "$policyAssignmentsFolder/tree-optimized.$FileExtension"
# $object = Get-HashtableWithPropertyNamesRemoved -Object $assignmentsByPolicyDefinition -PropertyNames "parent", "clusters"
# $json = ConvertTo-Json $object -Depth 100
# $null = New-Item $fullPath -Force -ItemType File -Value $json
# $assignmentsByPolicyDefinition = $object

#endregion prep tree for collapsing nodes

#region create assignment files (one per definition id), use clusters to collapse tree

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Creating $($assignmentsByPolicyDefinition.psbase.Count) Policy Assignment files"
Write-Information "==================================================================================================="

foreach ($policyDefinitionKey in $assignmentsByPolicyDefinition.Keys) {
    $perDefinition = $assignmentsByPolicyDefinition.$policyDefinitionKey
    Out-PolicyAssignmentFile `
        -PerDefinition $perDefinition `
        -PropertyNames $propertyNames `
        -PolicyAssignmentsFolder $policyAssignmentsFolder `
        -InvalidChars $invalidChars
}

#endregion create assignment files (one per definition id), use clusters to collapse tree
