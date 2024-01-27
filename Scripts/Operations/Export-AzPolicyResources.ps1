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
    e) 'psrule' exports EPAC environment into a file which can be used to create policy rules for PSRule for Azure

.PARAMETER InputPacSelector
Limits the collection to one EPAC environment, useful for non-interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'.
The default is '*' which will execute all EPAC-Environments.

.PARAMETER SuppressDocumentation
Suppress documentation generation.

.PARAMETER SuppressEpacOutput
Suppress output generation in EPAC format.

.PARAMETER PSRuleIgnoreFullScope
Ignore full scope for PsRule Extraction

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

    [ValidateSet("export", "collectRawFile", 'exportFromRawFiles', 'exportRawToPipeline', 'psrule')]
    [Parameter(Mandatory = $false, HelpMessage = "
        Operating mode:
        a) 'export' exports EPAC environments in EPAC format, should be used with -Interactive `$true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.
        b) 'collectRawFile' exports the raw data only; Often used with 'inputPacSelector' when running non-interactive in a multi-tenant scenario to collect the raw data once per tenant into a file named after the EPAC environment
        c) 'exportFromRawFiles' reads the files generated with one or more runs of b) and outputs the files the same as normal 'export'.
        d) 'exportRawToPipeline' exports EPAC environments in EPAC format, should be used with -Interactive `$true in a multi-tenant scenario, or use with an inputPacSelector to limit the scope to one EPAC environment.
        e) 'psrule' exports EPAC environment into a file which can be used to create policy rules for PSRule for Azure
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
    [switch] $SuppressEpacOutput,

    [Parameter(Mandatory = $false, HelpMessage = "Ignore full scope for PsRule Extraction")]
    [switch] $PSRuleIgnoreFullScope
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

#region Initialize

$InformationPreference = "Continue"
$includeAutoAssignedLocal = $IncludeAutoAssigned.IsPresent
# $includeAutoAssignedLocal = $true # uncomment for debugging
# $InputPacSelector = "tenant" # uncomment for debugging

$globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -InputFolder $inputFolder
$pacEnvironments = $globalSettings.pacEnvironments
$OutputFolder = $globalSettings.outputFolder
$exportFolder = "$($OutputFolder)/export"
$rawFolder = "$($exportFolder)/RawDefinitions"
$definitionsFolder = "$($exportFolder)/Definitions"
$policyDefinitionsFolder = "$definitionsFolder/policyDefinitions"
$policySetDefinitionsFolder = "$definitionsFolder/policySetDefinitions"
$policyAssignmentsFolder = "$definitionsFolder/policyAssignments"
$policyExemptionsFolder = "$definitionsFolder/policyExemptions"
$ownershipCsvPath = "$($exportFolder)/policy-ownership.csv"
$invalidChars = [IO.Path]::GetInvalidFileNameChars()
$invalidChars += (":[]()$".ToCharArray())

# Telemetry
if ($globalSettings.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("pid-dc5b73fd-e93c-40ca-8fef-976762d1d30") 
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

# Check if we have a valid mode
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
    "assignmentNameEx", # name, displayName, description
    "metadata",
    "parameters",
    "overrides",
    "resourceSelectors",
    "enforcementMode",
    "scopes",
    "notScopes",
    "nonComplianceMessages",
    "additionalRoleAssignments",
    "identityEntry"
)

$policyResourcesByPacSelector = @{}

#endregion Initialize

if ($Mode -ne 'exportFromRawFiles') {

    #region retrieve Policy resources

    foreach ($pacSelector in $globalSettings.pacEnvironmentSelectors) {

        $pacEnvironment = $pacEnvironments.$pacSelector

        if ($InputPacSelector -eq $pacSelector -or $InputPacSelector -eq '*') {
            $null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $Interactive
            if ($Mode -eq 'psrule' -and $PSRuleIgnoreFullScope -eq $false) {
                $pacEnvironmentOriginalScope = $pacEnvironment.deploymentRootScope
                $pacEnvironment.deploymentRootScope = "/providers/Microsoft.Management/managementGroups/$($pacEnvironment.tenantId)"
            }
            elseif ($Mode -eq 'psrule' -and $PSRuleIgnoreFullScope -eq $true) {
                $pacEnvironmentOriginalScope = $pacEnvironment.deploymentRootScope
            }
            $scopeTable = Get-AzScopeTree -PacEnvironment $pacEnvironment
            if ($Mode -eq 'psrule') {
                $newScopeTable = @{}
                foreach ($scope in $scopeTable.GetEnumerator()) {
                    if ($scope.Value.childrenList.ContainsKey($pacEnvironmentOriginalScope)) {
                        $newObj = $scope.Value | Select-Object -ExcludeProperty childrenList
                        $children = @{}
                        $scope.Value.childrenList.GetEnumerator() | Where-Object Key -eq $pacEnvironmentOriginalScope | ForEach-Object {
                            $children.Add($_.Key, $_.Value)
                        }
                        Add-Member -InputObject $newObj -MemberType NoteProperty -Name childrenList -Value $children
                        $newScopeTable.Add($newObj.id, $newObj)
                    }
                    elseif ($scope.Value.id -eq $pacEnvironmentOriginalScope) {
                        $newScopeTable.Add($scope.Value.id, $scope.Value)
                    }
                }
                $scopeTable = $newScopeTable
            }
            $skipExemptions = $ExemptionFiles -eq "none"
            $deployed = Get-AzPolicyResources -PacEnvironment $pacEnvironment -ScopeTable $scopeTable -SkipExemptions:$skipExemptions -CollectAllPolicies:$IncludeChildScopes

            $policyDefinitions = $deployed.policydefinitions.managed
            $policySetDefinitions = $deployed.policysetdefinitions.managed
            $policyAssignments = $deployed.policyassignments.managed
            $policyExemptions = $deployed.policyExemptions.managed

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

    if ($Mode -eq 'psrule') {
        # Export PsRule formatted output
        $outputArray = @()
        foreach ($policy in ($deployed.policyassignments.managed).GetEnumerator()) {
            $formattedObj = @{
                Location           = $policy.Value.location
                Name               = $policy.Value.Name
                ResourceId         = $policy.Value.ResourceId
                ResourceName       = $policy.Value.Name
                ResourceGroupName  = $policy.Value.ResourceGroupName
                ResourceType       = $policy.Value.ResourceType
                SubscriptionId     = $policy.Value.SubscriptionId
                Sku                = $policy.Value.Sku
                PolicyAssignmentId = $policy.Value.ResourceId
                Properties         = @{
                    Scope                 = $policy.Value.Properties.Scope
                    NotScope              = $policy.Value.Properties.NotScope
                    DisplayName           = $policy.Value.Properties.DisplayName
                    Description           = $policy.Value.Properties.Description
                    Metadata              = $policy.Value.Properties.Metadata
                    EnforcementMode       = switch ($policy.Value.Properties.EnforcementMode) {
                        0 { "Default" }
                        1 { "DoNotEnforce" }
                    }
                    PolicyDefinitionId    = $policy.Value.Properties.PolicyDefinitionId
                    Parameters            = $policy.Value.Properties.Parameters
                    NonComplianceMessages = $policy.Value.Properties.NonComplianceMessages
                }
            }
    
            if ($formattedObj.Properties.PolicyDefinitionId -match 'policyDefinitions') {
                $def = $deployed.policydefinitions.all[$formattedObj.Properties.PolicyDefinitionId]
                $pdObj = @{
                    Name               = $def.Name
                    ResourceId         = $def.ResourceId
                    ResourceName       = $def.name
                    ResourceType       = $def.type
                    SubscriptionId     = $def.SubscriptionId
                    Properties         = $def.properties
                    PolicyDefinitionId = $def.ResourceId
                }
                $formattedObj.PolicyDefinitions = @($pdObj)
            }
            else {
                $defList = ($deployed.policysetdefinitions.all[$formattedObj.Properties.PolicyDefinitionId].properties.policyDefinitions).policyDefinitionId
                $defArray = @()
                foreach ($def in $defList) {
                    $defObject = $deployed.policydefinitions.all[$def]
                    $pdObj = @{
                        Name               = $defObject.Name
                        ResourceId         = $defObject.ResourceId
                        ResourceName       = $defObject.name
                        ResourceType       = $defObject.type
                        SubscriptionId     = $defObject.SubscriptionId
                        Properties         = $defObject.properties
                        PolicyDefinitionId = $defObject.ResourceId
                    }
                    $defArray += $pdObj
                }
                $formattedObj.PolicyDefinitions = $defArray
            }
    
            $outputArray += $formattedObj
        }

        $outputArray | ConvertTo-Json -Depth 100 | Out-File -FilePath "$OutputFolder/psrule.assignment.json" -Force
        return 0
    }

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
        try {
            $policyResources = $Json | ConvertFrom-Json -Depth 100 -AsHashTable
        }
        catch {
            Write-Error "Assignment JSON file '$($file.FullName)' is not valid." -ErrorAction Stop
        }
        $currentPacSelector = $file.BaseName
        $policyResourcesByPacSelector[$currentPacSelector] = $policyResources
    }
}

[System.Collections.ArrayList] $allRows = [System.Collections.ArrayList]::new()

foreach ($pacSelector in $globalSettings.pacEnvironmentSelectors) {

    $pacEnvironment = $pacEnvironments.$pacSelector

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
            $rawMetadata = $properties.metadata

            #region Collect ownership info for CSV file

            $rowObj = [ordered]@{}
            $rowObj.pacSelector = $pacSelector
            $rowObj.kind = "Policy"
            if ($policyDefinition.pacOwner -eq "otherPaC") {
                $rowObj.owner = "otherPaC($($rawMetadata.pacOwnerId))"
            }
            else {
                $rowObj.owner = $policyDefinition.pacOwner
            }
            if ($null -ne $rawMetadata.category) {
                $rowObj.category = $rawMetadata.category
            }
            else {
                $rowObj.category = ""
            }
            $rowObj.displayName = $properties.displayName
            $rowObj.id = $policyDefinition.id
            $null = $allRows.Add($rowObj)

            #endregion Collect ownership info for CSV file

            # Collect Policy Properties
            $metadata = Get-CustomMetadata $rawMetadata -Remove "pacOwnerId"
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
            $rawMetadata = $properties.metadata

            #region Collect ownership info for CSV file

            $rowObj = [ordered]@{}
            $rowObj.pacSelector = $pacSelector
            $rowObj.kind = "Policy Set"
            if ($policySetDefinition.pacOwner -eq "otherPaC") {
                $rowObj.owner = "otherPaC($($rawMetadata.pacOwnerId))"
            }
            else {
                $rowObj.owner = $policySetDefinition.pacOwner
            }
            if ($null -ne $rawMetadata.category) {
                $rowObj.category = $rawMetadata.category
            }
            else {
                $rowObj.category = ""
            }
            $rowObj.displayName = $properties.displayName
            $rowObj.id = $policySetDefinition.id
            $null = $allRows.Add($rowObj)

            #endregion Collect ownership info for CSV file

            # Collect Policy Set Properties
            $metadata = Get-CustomMetadata $rawMetadata -Remove "pacOwnerId"
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

        #region Policy Assignments collate multiple entries by policyDefinitionId

        Write-Information ""
        Write-Information "==================================================================================================="
        Write-Information "Collating $($policyAssignments.psbase.Count) Policy Assignments from EPAC environment '$pacSelector'"
        Write-Information "==================================================================================================="

        foreach ($policyAssignment in $policyAssignments.Values) {
            $id = $policyAssignment.id
            $properties = Get-PolicyResourceProperties -PolicyResource $policyAssignment
            $rawMetadata = $properties.metadata

            if ($policyAssignment.pacOwner -eq "managedByDfcSecurityPolicies" -or $policyAssignment.pacOwner -eq "managedByDfcDefenderPlans") {
                if (!$includeAutoAssignedLocal) {
                    Write-Warning "Skip DfC Assignment: $($properties.displayName)($id)"
                    continue
                }
            }

            #region Collect ownership info for CSV file

            $rowObj = [ordered]@{}
            $rowObj.pacSelector = $pacSelector
            $policyDefinitionId = $properties.policyDefinitionId
            $parts = Split-AzPolicyResourceId -Id $policyDefinitionId
            $policyKind = if ($parts.kind -eq "policyDefinitions") { "Policy" } else { "PolicySet" }
            $policyType = if ($parts.scopeType -eq "builtin") { "Builtin" } else { "Custom" }
            $rowObj.kind = "Assignment($($policyKind)-$($policyType))"
            if ($policyAssignment.pacOwner -eq "otherPaC") {
                $rowObj.owner = "otherPaC($($rawMetadata.pacOwnerId))"
            }
            else {
                $rowObj.owner = $policyAssignment.pacOwner
            }
            if ($null -ne $rawMetadata.category) {
                $rowObj.category = $rawMetadata.category
            }
            else {
                $rowObj.category = ""
            }
            $rowObj.displayName = $properties.displayName
            $rowObj.id = $policyAssignment.id
            $null = $allRows.Add($rowObj)

            #endregion Collect ownership info for CSV file

            $roles = @()
            if ($rawMetadata.roles) {
                $roles = $rawMetadata.roles
            }
            $metadata = Get-CustomMetadata $properties.metadata -Remove "pacOwnerId,roles"

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
                $location = $null
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

        #endregion Policy Assignments collate multiple entries by policyDefinitionId

        #region process Exemptions

        if (-not $skipExemptions) {

            #region Collect ownership info for CSV file

            $selectedExemptions = $policyExemptions.Values
            foreach ($exemption in $selectedExemptions) {
                $rowObj = [ordered]@{}
                $rowObj.pacSelector = $pacSelector
                $rowObj.kind = "Exemption($($exemption.status))"
                $rawMetadata = $exemption.metadata
                if ($exemption.pacOwner -eq "otherPaC") {
                    $rowObj.owner = "otherPaC($($rawMetadata.pacOwnerId))"
                }
                else {
                    $rowObj.owner = $exemption.pacOwner
                }
                $rowObj.category = $exemption.exemptionCategory
                $rowObj.displayName = $exemption.displayName
                $rowObj.id = $exemption.id
                $null = $allRows.Add($rowObj)
            }

            #endregion Collect ownership info for CSV file

            Write-Information ""
            Out-PolicyExemptions `
                -Exemptions $policyExemptions `
                -PacEnvironment $pacEnvironment `
                -PolicyExemptionsFolder $policyExemptionsFolder `
                -OutputJson:($ExemptionFiles -eq "json") `
                -OutputCsv:($ExemptionFiles -eq "csv") `
                -FileExtension $FileExtension `
                -ActiveExemptionsOnly
        }

        #endregion process Exemptions

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

#region Output Ownership CSV file

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Creating Ownership CSV file"
Write-Information "==================================================================================================="
$null = New-Item $ownershipCsvPath -Force -ItemType File
$allRows | Export-Csv -Path $ownershipCsvPath -NoTypeInformation -Encoding UTF8
