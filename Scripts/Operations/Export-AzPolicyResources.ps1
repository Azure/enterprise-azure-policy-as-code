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
Set to false if used non-Interactive. Defaults to $true.

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
    b) 'collectRawFile' exports the raw data only; Often used with 'inputPacSelector' when running non-Interactive in a multi-tenant scenario to collect the raw data once per tenant into a file named after the EPAC environment
    c) 'exportFromRawFiles' reads the files generated with one or more runs of b) and outputs the files the same as normal 'export'.
    d) 'exportRawToPipeline' exports EPAC environments in EPAC format, should be used with -Interactive $true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.

.PARAMETER InputPacSelector
Limits the collection to one EPAC environment, useful for non-Interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'.
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
https://azure.github.io/enterprise-azure-Policy-as-code/extract-Existing-Policy-resources
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-Interactive")]
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
        b) 'collectRawFile' exports the raw data only; Often used with 'inputPacSelector' when running non-Interactive in a multi-tenant scenario to collect the raw data once per tenant into a file named after the EPAC environment
        c) 'exportFromRawFiles' reads the files generated with one or more runs of b) and outputs the files the same as normal 'export'.
        d) 'exportRawToPipeline' exports EPAC environments in EPAC format, should be used with -Interactive `$true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.
    ")]
    [string] $Mode = 'export',
    # [string] $Mode = 'collectRawFile',
    # [string] $Mode = 'exportFromRawFiles',
    # [string] $Mode = 'exportRawToPipeline',

    [Parameter(Mandatory = $false, HelpMessage = "
        Limits the collection to one EPAC environment, useful for non-Interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'.
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
$globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -InputFolder $InputFolder
$PacEnvironments = $globalSettings.pacEnvironments
$OutputFolder = $globalSettings.outputFolder
$rawFolder = "$($OutputFolder)/RawDefinitions"
$DefinitionsFolder = "$($OutputFolder)/Definitions"
$PolicyDefinitionsFolder = "$DefinitionsFolder/policyDefinitions"
$PolicySetDefinitionsFolder = "$DefinitionsFolder/policySetDefinitions"
$PolicyAssignmentsFolder = "$DefinitionsFolder/policyAssignments"
$PolicyExemptionsFolder = "$DefinitionsFolder/policyExemptions"
$InvalidChars = [IO.Path]::GetInvalidFileNameChars()
$InvalidChars += ("[]()$".ToCharArray())
Write-Information "Mode: $Mode"
if ($Mode -eq 'export' -or $Mode -eq 'exportFromRawFiles') {
    if (Test-Path $DefinitionsFolder) {
        if ($Interactive) {
            Write-Information ""
            Remove-Item $DefinitionsFolder -Recurse -Confirm
            Write-Information ""
        }
        else {
            Remove-Item $DefinitionsFolder -Recurse
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

$PolicyPropertiesByName = @{}
$PolicySetPropertiesByName = @{}
$DefinitionPropertiesByDefinitionKey = @{}
$AssignmentsByPolicyDefinition = @{}

$PropertyNames = @(
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

$PolicyResourcesByPacSelector = @{}

#endregion Initialize

if ($Mode -ne 'exportFromRawFiles') {

    #region retrieve Policy resources

    foreach ($PacEnvironment in $PacEnvironments.Values) {

        $PacSelector = $PacEnvironment.pacSelector

        if ($InputPacSelector -eq $PacSelector -or $InputPacSelector -eq '*') {
            Set-AzCloudTenantSubscription -Cloud $PacEnvironment.cloud -TenantId $PacEnvironment.tenantId -Interactive $Interactive

            $ScopeTable = Get-AzScopeTree -PacEnvironment $PacEnvironment
            $SkipExemptions = $ExemptionFiles -eq "none"
            $deployed = Get-AzPolicyResources -PacEnvironment $PacEnvironment -ScopeTable $ScopeTable -SkipExemptions:$SkipExemptions -CollectAllPolicies:$IncludeChildScopes

            $PolicyDefinitions = $deployed.policydefinitions.custom
            $PolicySetDefinitions = $deployed.policysetdefinitions.custom
            $PolicyAssignments = $deployed.policyassignments.all
            $PolicyExemptions = $deployed.policyExemptions.all

            $PolicyResources = @{
                policyDefinitions    = $PolicyDefinitions
                policySetDefinitions = $PolicySetDefinitions
                policyAssignments    = $PolicyAssignments
                policyExemptions     = $PolicyExemptions
            }
            $PolicyResourcesByPacSelector[$PacSelector] = $PolicyResources

            if ($Mode -eq 'collectRawFile') {
                # write file
                $fullPath = "$rawFolder/$PacSelector.json"
                $json = ConvertTo-Json $PolicyResources -Depth 100
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
        Write-Output $PolicyResourcesByPacSelector
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
        $PolicyResources = $Json | ConvertFrom-Json -Depth 100 -AsHashtable
        $currentPacSelector = $file.BaseName
        $PolicyResourcesByPacSelector[$currentPacSelector] = $PolicyResources
    }
}

foreach ($PacEnvironment in $PacEnvironments.Values) {

    $PacSelector = $PacEnvironment.pacSelector

    if (($InputPacSelector -eq $PacSelector -or $InputPacSelector -eq '*') -and $PolicyResourcesByPacSelector.ContainsKey($PacSelector)) {

        $PolicyResources = $PolicyResourcesByPacSelector.$PacSelector
        $PolicyDefinitions = $PolicyResources.policyDefinitions
        $PolicySetDefinitions = $PolicyResources.policySetDefinitions
        $PolicyAssignments = $PolicyResources.policyAssignments
        $PolicyExemptions = $PolicyResources.policyExemptions

        #region Policy definitions

        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Processing $($PolicyDefinitions.psbase.Count) Policies from EPAC environment '$PacSelector'"
        Write-Information "==================================================================================================="

        foreach ($PolicyDefinition in $PolicyDefinitions.Values) {
            $properties = Get-PolicyResourceProperties -PolicyResource $PolicyDefinition
            $Metadata = Get-CustomMetadata $properties.metadata -Remove "pacOwnerId"
            $version = $properties.version
            $Id = $PolicyDefinition.id
            $Name = $PolicyDefinition.name
            # if ($null -eq $version) {
            #     if ($Metadata.version) {
            #         $version = $Metadata.version
            #     }
            #     else {
            #         $version = 1.0.0
            #     }
            # }

            $Definition = [PSCustomObject]@{
                name       = $Name
                properties = [PSCustomObject]@{
                    displayName = $properties.displayName
                    description = $properties.description
                    mode        = $properties.mode
                    metadata    = $Metadata
                    version     = $version
                    parameters  = $properties.parameters
                    policyRule  = [PSCustomObject]@{
                        if   = $properties.policyRule.if
                        then = $properties.policyRule.then
                    }
                }
            }
            Out-PolicyDefinition `
                -Definition $Definition `
                -Folder $PolicyDefinitionsFolder `
                -PolicyPropertiesByName $PolicyPropertiesByName `
                -InvalidChars $InvalidChars `
                -Id $Id `
                -FileExtension $FileExtension
        }

        # cache properties per definition key
        $Definitions = $deployed.policydefinitions.all
        foreach ($Id in $Definitions.Keys) {
            $parts = Split-AzPolicyResourceId -Id $Id
            $PolicyDefinitionKey = $parts.definitionKey
            $Definition = $Definitions.$Id
            if (!($DefinitionPropertiesByDefinitionKey.ContainsKey($PolicyDefinitionKey))) {
                $DefinitionPropertiesByDefinitionKey[$PolicyDefinitionKey] = $Definition.properties
            }
        }

        #endregion Policy definitions

        #region Policy Set definitions

        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Processing $($PolicySetDefinitions.psbase.Count) Policy Sets from EPAC environment '$PacSelector'"
        Write-Information "==================================================================================================="

        foreach ($PolicySetDefinition in $PolicySetDefinitions.Values) {
            $properties = Get-PolicyResourceProperties -PolicyResource $PolicySetDefinition
            $Metadata = Get-CustomMetadata $properties.metadata -Remove "pacOwnerId"
            $version = $properties.version
            # if ($null -eq $version) {
            #     if ($Metadata.version) {
            #         $version = $Metadata.version
            #     }
            #     else {
            #         $version = 1.0.0
            #     }
            # }

            # Adjust policyDefinitions for EPAC
            $PolicyDefinitionsIn = Get-DeepClone $properties.policyDefinitions -AsHashtable
            $PolicyDefinitionsOut = [System.Collections.ArrayList]::new()
            foreach ($PolicyDefinitionIn in $PolicyDefinitionsIn) {
                $parts = Split-AzPolicyResourceId -Id $PolicyDefinitionIn.policyDefinitionId
                $PolicyDefinitionOut = $null
                if ($parts.scopeType -eq "builtin") {
                    $PolicyDefinitionOut = [PSCustomObject]@{
                        policyDefinitionReferenceId = $PolicyDefinitionIn.policyDefinitionReferenceId
                        policyDefinitionId          = $PolicyDefinitionIn.policyDefinitionId
                        parameters                  = $PolicyDefinitionIn.parameters
                    }
                }
                else {
                    $PolicyDefinitionOut = [PSCustomObject]@{
                        policyDefinitionReferenceId = $PolicyDefinitionIn.policyDefinitionReferenceId
                        policyDefinitionName        = $parts.name
                        parameters                  = $PolicyDefinitionIn.parameters
                    }
                }
                if ($PolicyDefinitionIn.definitionVersion) {
                    Add-Member -InputObject $PolicyDefinitionOut -TypeName "NoteProperty" -NotePropertyName "definitionVersion" -NotePropertyValue $PolicyDefinitionIn.definitionVersion
                }
                $groupNames = $PolicyDefinitionIn.groupNames
                if ($null -ne $groupNames -and $groupNames.Count -gt 0) {
                    Add-Member -InputObject $PolicyDefinitionOut -TypeName "NoteProperty" -NotePropertyName "groupNames" -NotePropertyValue $groupNames
                }
                $null = $PolicyDefinitionsOut.Add($PolicyDefinitionOut)
            }

            $Definition = [PSCustomObject]@{
                name       = $PolicySetDefinition.name
                properties = [PSCustomObject]@{
                    displayName            = $properties.displayName
                    description            = $properties.description
                    metadata               = $Metadata
                    version                = $version
                    parameters             = $properties.parameters
                    policyDefinitions      = $PolicyDefinitionsOut.ToArray()
                    policyDefinitionGroups = $properties.policyDefinitionGroups
                }
            }
            Out-PolicyDefinition `
                -Definition $Definition `
                -Folder $PolicySetDefinitionsFolder `
                -PolicyPropertiesByName $PolicySetPropertiesByName `
                -InvalidChars $InvalidChars `
                -Id $PolicySetDefinition.id `
                -FileExtension $FileExtension
        }

        # cache properties per definition key
        $Definitions = $deployed.policysetdefinitions.all
        foreach ($Id in $Definitions.Keys) {
            $parts = Split-AzPolicyResourceId -Id $Id
            $PolicyDefinitionKey = $parts.definitionKey
            $Definition = $Definitions.$Id
            if (!($DefinitionPropertiesByDefinitionKey.ContainsKey($PolicyDefinitionKey))) {
                $DefinitionPropertiesByDefinitionKey[$PolicyDefinitionKey] = $Definition.properties
            }
        }

        #endregion Policy Set definitions

        #region process Exemptions

        if (-not $SkipExemptions) {
            Out-PolicyExemptions `
                -Exemptions $PolicyExemptions `
                -Assignments $PolicyAssignments `
                -PacEnvironment $PacEnvironment `
                -PolicyExemptionsFolder $PolicyExemptionsFolder `
                -OutputJson:($ExemptionFiles -eq "json") `
                -OutputCsv:($ExemptionFiles -eq "csv") `
                -ExemptionOutputType "active" `
                -FileExtension $FileExtension
        }

        #endregion process Exemptions

        #region Policy Assignments collate multiple entries by policyDefinitionId

        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Collating $($PolicyAssignments.psbase.Count) Policy Assignments from EPAC environment '$PacSelector'"
        Write-Information "==================================================================================================="

        foreach ($PolicyAssignment in $PolicyAssignments.Values) {
            $Id = $PolicyAssignment.id
            if (!$IncludeAutoAssigned -and `
                (
                    $Id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/ASC-*" `
                        -or $Id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/SecurityCenterBuiltIn"
                )
            ) {
                Write-Warning "Do not process Security Center: $Id"
            }
            else {
                $properties = Get-PolicyResourceProperties -PolicyResource $PolicyAssignment
                $rawMetadata = $properties.metadata
                $roles = @()
                if ($rawMetadata.roles) {
                    $roles = $rawMetadata.roles
                }
                $Metadata = Get-CustomMetadata $properties.metadata -Remove "pacOwnerId, roles"

                $Name = $PolicyAssignment.name
                $PolicyDefinitionId = $properties.policyDefinitionId
                $parts = Split-AzPolicyResourceId -Id $PolicyDefinitionId
                $PolicyDefinitionKey = $parts.definitionKey
                $enforcementMode = $properties.enforcementMode
                $DisplayName = $PolicyAssignment.name
                if ($null -ne $properties.displayName -and $properties.displayName -ne "") {
                    $DisplayName = $properties.displayName
                }
                $DisplayName = $properties.name
                if ($null -ne $properties.displayName -and $properties.displayName -ne "") {
                    $DisplayName = $properties.displayName
                }
                $description = ""
                if ($null -ne $properties.description) {
                    $description = $properties.description
                }
                $AssignmentNameEx = @{
                    name        = $Name
                    displayName = $DisplayName
                    description = $description
                }

                $Scope = $PolicyAssignment.resourceIdParts.scope
                $NotScopes = Remove-GlobalNotScopes `
                    -NotScopes $PolicyAssignment.notScopes `
                    -GlobalNotScopes $PacEnvironment.globalNotScopes
                if ($NotScopes.Count -eq 0) {
                    $NotScopes = $null
                }

                $additionalRoleAssignments = [System.Collections.ArrayList]::new()
                foreach ($role in $roles) {
                    if ($Scope -ne $role.scope) {
                        $roleAssignment = @{
                            roleDefinitionId = $role.roleDefinitionId
                            scope            = $role.scope
                        }
                        $null = $additionalRoleAssignments.Add($roleAssignment)
                    }
                }

                $IdentityEntry = $null
                $IdentityType = $PolicyAssignment.identity.type
                $location = $PolicyAssignment.location
                if ($location -eq $PacEnvironment.managedIdentityLocation) {
                    $location = ""
                }
                if ($IdentityType -eq "UserAssigned") {
                    $userAssignedIdentities = $PolicyAssignment.identity.userAssignedIdentities
                    $IdentityProperty = $userAssignedIdentities.psobject.Properties
                    $Identity = $IdentityProperty.Name
                    $IdentityEntry = @{
                        userAssigned = $Identity
                        location     = $location
                    }
                }
                elseif ($IdentityType -eq "SystemAssigned") {
                    $IdentityEntry = @{
                        userAssigned = $null
                        location     = $location
                    }
                }

                $Parameters = @{}
                if ($null -ne $properties.parameters -and $properties.parameters.psbase.Count -gt 0) {
                    $ParametersClone = Get-DeepClone $properties.parameters -AsHashtable
                    foreach ($parameterName in $ParametersClone.Keys) {
                        $parameterValue = $ParametersClone.$parameterName
                        $Parameters[$parameterName] = $parameterValue.value
                    }
                }
                $overrides = $properties.overrides
                $resourceSelectors = $properties.resourceSelectors

                $nonComplianceMessages = $null
                if ($properties.nonComplianceMessages -and $properties.nonComplianceMessages.Count -gt 0) {
                    $nonComplianceMessages = $properties.nonComplianceMessages
                }

                $PerDefinition = $null

                $PropertiesList = @{
                    parameters                = $Parameters
                    overrides                 = $overrides
                    resourceSelectors         = $resourceSelectors
                    enforcementMode           = $enforcementMode
                    nonComplianceMessages     = $nonComplianceMessages
                    additionalRoleAssignments = $additionalRoleAssignments
                    assignmentNameEx          = $AssignmentNameEx
                    metadata                  = $Metadata
                    identityEntry             = $IdentityEntry
                    scopes                    = $Scope
                    notScopes                 = $NotScopes
                }

                $PerDefinition = $null
                if (-not $AssignmentsByPolicyDefinition.ContainsKey($PolicyDefinitionKey)) {
                    $DefinitionProperties = $DefinitionPropertiesByDefinitionKey.$PolicyDefinitionKey
                    $PerDefinition = @{
                        parent          = $null
                        clusters        = @{}
                        children        = [System.Collections.ArrayList]::new()
                        definitionEntry = @{
                            definitionKey = $PolicyDefinitionKey
                            id            = $parts.id
                            name          = $parts.name
                            displayName   = $DefinitionProperties.displayName
                            scope         = $parts.scope
                            scopeType     = $parts.scopeType
                            kind          = $parts.kind
                            isBuiltin     = $parts.scopeType -eq "builtin"
                        }
                    }
                    $null = $AssignmentsByPolicyDefinition.Add($PolicyDefinitionKey, $PerDefinition)
                }
                else {
                    $PerDefinition = $AssignmentsByPolicyDefinition.$PolicyDefinitionKey
                }
                Set-ExportNode -ParentNode $PerDefinition -PacSelector $PacSelector -PropertyNames $PropertyNames -PropertiesList $PropertiesList -CurrentIndex 0

            }
        }
        #endregion Policy Assignments collate multiple entries by policyDefinitionId

    }
}

#region prep tree for collapsing nodes

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Optimizing $($AssignmentsByPolicyDefinition.psbase.Count) Policy Assignment trees"
Write-Information "==================================================================================================="

# $fullPath = "$PolicyAssignmentsFolder/tree-raw.$FileExtension"
# $Object = Get-HashtableWithPropertyNamesRemoved -Object $AssignmentsByPolicyDefinition -PropertyNames "parent", "clusters"
# $json = ConvertTo-Json $Object -Depth 100
# $null = New-Item $fullPath -Force -ItemType File -Value $json

foreach ($PolicyDefinitionKey in $AssignmentsByPolicyDefinition.Keys) {
    $PerDefinition = $AssignmentsByPolicyDefinition.$PolicyDefinitionKey
    foreach ($child in $PerDefinition.children) {
        Set-ExportNodeAncestors `
            -CurrentNode $child `
            -PropertyNames $PropertyNames `
            -CurrentIndex 0
    }
}

# $fullPath = "$PolicyAssignmentsFolder/tree-optimized.$FileExtension"
# $Object = Get-HashtableWithPropertyNamesRemoved -Object $AssignmentsByPolicyDefinition -PropertyNames "parent", "clusters"
# $json = ConvertTo-Json $Object -Depth 100
# $null = New-Item $fullPath -Force -ItemType File -Value $json
# $AssignmentsByPolicyDefinition = $Object

#endregion prep tree for collapsing nodes

#region create assignment files (one per definition id), use clusters to collapse tree

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Creating $($AssignmentsByPolicyDefinition.psbase.Count) Policy Assignment files"
Write-Information "==================================================================================================="

foreach ($PolicyDefinitionKey in $AssignmentsByPolicyDefinition.Keys) {
    $PerDefinition = $AssignmentsByPolicyDefinition.$PolicyDefinitionKey
    Out-PolicyAssignmentFile `
        -PerDefinition $PerDefinition `
        -PropertyNames $PropertyNames `
        -PolicyAssignmentsFolder $PolicyAssignmentsFolder `
        -InvalidChars $InvalidChars
}

#endregion create assignment files (one per definition id), use clusters to collapse tree
