#Requires -PSEdition Core

[CmdletBinding()]
param (
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $outputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Switch to include Policies and Policy Sets definitions in child scopes")]
    [switch] $includeChildScopes
)

#region Script Dot sourcing

# Common Functions
. "$PSScriptRoot/../Helpers/Build-NotScopes.ps1"

. "$PSScriptRoot/../Helpers/Confirm-AssignmentParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ObjectValueEqualityDeep.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PacOwner.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

. "$PSScriptRoot/../Helpers/Get-AzPolicyResources.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/Get-CustomMetadata.ps1"
. "$PSScriptRoot/../Helpers/Get-DeepClone.ps1"
. "$PSScriptRoot/../Helpers/Get-DefinitionsFullPath.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Get-HashtableShallowClone.ps1"
. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-PolicyResourceProperties.ps1"
. "$PSScriptRoot/../Helpers/Get-ScrubbedString.ps1"

. "$PSScriptRoot/../Helpers/Out-PolicyDefinition.ps1"

. "$PSScriptRoot/../Helpers/Search-AzGraphAllItems.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"
. "$PSScriptRoot/../Helpers/Split-ScopeId.ps1"
. "$PSScriptRoot/../Helpers/Split-AzPolicyResourceId.ps1"
. "$PSScriptRoot/../Helpers/Switch-PacEnvironment.ps1"

#endregion dot sourcing

#region Initialize

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
$pacSelector = $pacEnvironment.pacSelector
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive

$outputFolder = $pacEnvironment.outputFolder
$definitionsFolder = "$($pacEnvironment.outputFolder)/Definitions"
$policyDefinitionsFolder = "$definitionsFolder/policyDefinitions"
$policySetDefinitionsFolder = "$definitionsFolder/policySetDefinitions"
$policyAssignmentsFolder = "$definitionsFolder/policyAssignments"
$invalidChars = [IO.Path]::GetInvalidFileNameChars()
$invalidChars += ("[]()$".ToCharArray())
$globalNotScopesList = [System.Collections.ArrayList]::new()
foreach ($notScope in $pacEnvironment.globalNotScopes) {
    if ($notScope.StartsWith("/resourceGroupPatterns/")) {
        $notScope = $notScope -replace "/resourceGroupPatterns/", "/subscriptions/*/resourceGroups/"
    }
    $null = $globalNotScopesList.Add($notScope)
}
$globalNotScopes = $globalNotScopesList |  Sort-Object | Get-Unique
if (Test-Path $definitionsFolder) {
    if ($interactive) {
        Write-Information ""
        Remove-Item $definitionsFolder -Recurse -Confirm
        Write-Information ""
    }
    else {
        Remove-Item $definitionsFolder -Recurse
    }
}

# Retrieve Policy resources
$scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
$deployed = Get-AzPolicyResources -pacEnvironment $pacEnvironment -scopeTable $scopeTable -skipRoleAssignments -skipExemptions -collectAllPolicies:$includeChildScopes

$policyDefinitions = $deployed.policydefinitions.custom
$policySetDefinitions = $deployed.policysetdefinitions.custom
$policyAssignments = $deployed.policyassignments.all
$allDefinitions = @{}

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Processing $($policyDefinitions.Count) Policies"
Write-Information "==================================================================================================="

$policyNames = @{}
foreach ($policyDefinition in $policyDefinitions.Values) {
    $properties = Get-PolicyResourceProperties -policyResource $policyDefinition
    $metadata = Get-CustomMetadata $properties.metadata -remove "pacOwnerId"
    $version = $properties.version
    $id = $policyDefinition.id
    $name = $policyDefinition.name
    if ($null -eq $version) {
        $version = "1.0.0"
    }
    $definition = [PSCustomObject]@{
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
        name       = $name
    }
    Out-PolicyDefinition -definition $definition -folder $policyDefinitionsFolder -policyNames $policyNames -invalidChars $invalidChars -typeString "Policy" -id $id
}

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Processing $($policySetDefinitions.Count) Policy Sets"
Write-Information "==================================================================================================="

$policySetNames = @{}
foreach ($policySetDefinition in $policySetDefinitions.Values) {
    $properties = Get-PolicyResourceProperties -policyResource $policySetDefinition
    $metadata = Get-CustomMetadata $properties.metadata -remove "pacOwnerId"
    $version = $properties.version
    if ($null -eq $version) {
        $version = "1.0.0"
    }

    # Adjust policyDefinitions for EPAC
    $policyDefinitionsIn = Get-DeepClone $properties.policyDefinitions -AsHashTable
    $policyDefinitionsOut = [System.Collections.ArrayList]::new()
    foreach ($policyDefinitionIn in $policyDefinitionsIn) {
        $parts = Split-AzPolicyResourceId -id $policyDefinitionIn.policyDefinitionId
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
        $groupNames = $policyDefinitionIn.groupNames
        if ($null -ne $groupNames -and $groupNames.Count -gt 0) {
            Add-Member -InputObject $policyDefinitionOut -TypeName "NoteProperty" -NotePropertyName "groupNames" -NotePropertyValue $groupNames
        }
        $null = $policyDefinitionsOut.Add($policyDefinitionOut)
    }

    $definition = [PSCustomObject]@{
        properties = [PSCustomObject]@{
            displayName            = $properties.displayName
            description            = $properties.description
            metadata               = $metadata
            version                = $version
            parameters             = $properties.parameters
            policyDefinitions      = $policyDefinitionsOut.ToArray()
            policyDefinitionGroups = $properties.policyDefinitionGroups
        }
        name       = $policySetDefinition.name
    }
    Out-PolicyDefinition -definition $definition -folder $policySetDefinitionsFolder -policyNames $policySetNames -invalidChars $invalidChars -typeString "Policy" -id $policySetDefinition.id
}

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Processing $($policyAssignments.Count) Policy Assignments"
Write-Information "==================================================================================================="
Write-Information "WARNING! This script assumes the following:"
Write-Information "* Names of Policies and Policy Sets are unique across multiple scopes."
Write-Information "* Assignment names are the same if the parameters match across multiple assignments across scopes."
Write-Information "* Ignores Assignments auto-assigned by Security Center."
Write-Information "* Does not collate across multiple tenants."
Write-Information "* Does not calculate any additionalRoleAssignments."
Write-Information "==================================================================================================="

# Collate multiple entries by policyDefinitionId and than by scope and also parameters
$assignments = @{}
foreach ($policyAssignment in $policyAssignments.Values) {
    $id = $policyAssignment.id
    if ($id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/ASC-*" -or $id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/SecurityCenterBuiltIn") {
        # Write-Warning "Do not process Security Center: $id"
    }
    else {
        # Important elements
        $properties = Get-PolicyResourceProperties -policyResource $policyAssignment
        $metadata = Get-CustomMetadata $properties.metadata -remove "pacOwnerId,roles"
        $name = $policyAssignment.name
        $scope = $policyAssignment.resourceIdParts.scope
        $parameters = @{}
        if ($null -ne $properties.parameters -and $properties.parameters.Count -gt 0) {
            $parameters = Get-DeepClone $properties.parameters -AsHashTable
        }
        $policyDefinitionId = $properties.policyDefinitionId

        # Generate key for hashtable
        $parts = Split-AzPolicyResourceId -id $policyDefinitionId
        $policyDefinitionKey = $parts.definitionKey

        # Fill structure
        $perDefinition = $null
        if ($assignments.ContainsKey($policyDefinitionKey)) {
            $perDefinition = $assignments.$policyDefinitionKey

            # Collate by parameter cluster
            $match = $false
            $parameterClusters = $perDefinition.parameterClusters
            foreach ($clusterParameters in $parameterClusters.Keys) {
                # Find a match for clustering
                $perParameterCluster = $parameterClusters.$clusterParameters
                $localMatch = Confirm-AssignmentParametersMatch -existingParametersObj $clusterParameters -definedParametersObj $parameters -compareTwoExistingParametersObj
                if ($localMatch) {
                    # Add to existing cluster
                    $match = $true
                    $perParameterCluster[$id] = $policyAssignment
                    break
                }
            }
            if (!$match) {
                # Start a new cluster
                $parameterClusters = $perDefinition.parameterClusters
                $parameterClusters[$parameters] = @{
                    $id = $policyAssignment
                }
            }
        }
        else {
            # Initialize structure with first entry
            $definitions = $deployed.policysetdefinitions.all
            if ($parts.kind -eq "policyDefinitions") {
                $definitions = $deployed.policydefinitions.all
            }
            $definition = $definitions.$policyDefinitionId
            $definitionDisplayName = $definition.properties.displayName
            $perDefinition = @{
                parameterClusters     = @{
                    $parameters = @{
                        $id = $policyAssignment
                    }
                }
                definitionId          = $parts.id
                definitionName        = $parts.name
                definitionDisplayName = $definitionDisplayName
                definitionKind        = $parts.kind
                isBuiltin             = $parts.scopeType -eq "builtin"
            }
            $assignments[$policyDefinitionKey] = $perDefinition
        }
    }
}

foreach ($policyDefinitionKey in $assignments.Keys) {
    $perDefinition = $assignments.$policyDefinitionKey
    $parameterClusters = $perDefinition.parameterClusters

    $subfolder = $perDefinition.definitionKind -replace "Definitions", ""
    $fullPath = Get-DefinitionsFullPath `
        -folder $policyAssignmentsFolder `
        -rawSubFolder $subFolder `
        -name $perDefinition.definitionName `
        -displayName $perDefinition.definitionDisplayName `
        -invalidChars $invalidChars `
        -maxLengthSubFolder 30 `
        -maxLengthFileName 100

    # Create definitionEntry
    $definitionEntry = @{}
    if ($perDefinition.isBuiltin) {
        if ($perDefinition.definitionKind -eq "policySetDefinitions") {
            $definitionEntry = @{
                policySetId = $perDefinition.definitionId
                displayName = $perDefinition.definitionDisplayName
            }
        }
        else {
            $definitionEntry = @{
                policyId    = $perDefinition.definitionId
                displayName = $perDefinition.definitionDisplayName
            }
        }
    }
    else {
        # Custom
        $definition = $allDefinitions[$policyDefinitionKey]
        if ($perDefinition.definitionKind -eq "policySetDefinitions") {
            $definitionEntry = @{
                policySetName = $perDefinition.definitionName
                displayName   = $perDefinition.definitionDisplayName
            }
        }
        else {
            $definitionEntry = @{
                policyName  = $perDefinition.definitionName
                displayName = $perDefinition.definitionDisplayName
            }
        }
    }

    $assignmentDefinition = [ordered]@{
        nodeName        = "/root"
        definitionEntry = $definitionEntry
    }
    $children = [System.Collections.ArrayList]::new()
    foreach ($parameterSet in $parameterClusters.Keys) {

        $perParameterCluster = $parameterClusters.$parameterSet

        $flatParameters = @{}
        foreach ($parameterName in $parameterSet.Keys) {
            $flatParameters[$parameterName] = ($parameterSet[$parameterName]).value
        }

        $child = [ordered]@{}
        $grandChildren = [System.Collections.ArrayList]::new()
        $grandChildScopes = [System.Collections.ArrayList]::new()
        $allScopes = [System.Collections.ArrayList]::new()
        $allNotScopes = [System.Collections.ArrayList]::new()
        $allNotScopeProcessed = @{}
        foreach ($id in $perParameterCluster.Keys) {
            $currentAssignment = $perParameterCluster.$id
            $currentProperties = Get-PolicyResourceProperties -policyResource $currentAssignment
            $currentMetadata = Get-CustomMetadata $currentProperties.metadata -remove "pacOwnerId,roles"
            $grandChild = [ordered]@{
                nodeName        = "/$($currentAssignment.name)"
                assignment      = [ordered]@{
                    name        = $currentAssignment.name
                    displayName = $currentProperties.displayName
                    description = $currentProperties.description
                }
                metadata        = $currentMetadata
                enforcementMode = $currentProperties.enforcementMode
            }
            $location = $currentAssignment.location
            if ($null -ne $location -and $location -ne "global") {
                $grandChild.managedIdentityLocations = @{
                    $pacSelector = $location
                }
            }

            $scope = $currentAssignment.resourceIdParts.scope
            $null = $allScopes.Add($scope)
            $notScopeProcessed = @{}
            $notScopes = [System.Collections.ArrayList]::new()
            foreach ($notScope in $currentProperties.notScopes) {
                if (!($notScopeProcessed.ContainsKey($notScope))) {
                    # Is this a notScope not covered by a global notScope
                    $isInGlobalNotScopes = ($globalNotScopes | ForEach-Object { $notScope -like $_ }) -contains $true
                    if (!$isInGlobalNotScopes) {
                        # Only use notScopes not in globalNotScopes
                        $null = $notScopes.Add($notScope);
                        if (!($allNotScopeProcessed.ContainsKey($notScope))) {
                            $null = $allNotScopes.Add($notScope)
                        }
                    }
                    $notScopeProcessed[$notScope] = $true
                    $allNotScopeProcessed[$notScope] = $true
                }
            }

            $grandChildScope = @{
                scopes    = @( $scope )
                notScopes = $notScopes.ToArray()
            }
            $null = $grandChildren.Add($grandChild)
            $null = $grandChildScopes.Add($grandChildScope)
        }

        # Check if we can flatten the tree by folding grandChildren into child
        $previousGrandChild = @{}
        $match = $true
        foreach ($grandChild in $grandChildren) {
            if ($previousGrandChild.Count -ne 0) {
                if (!(Confirm-ObjectValueEqualityDeep -existingObj $previousGrandChild -definedObj $grandChild)) {
                    $match = $false
                }
            }
            $previousGrandChild = $grandChild
        }
        if ($match) {
            # we can flatten grandChildren into child
            $child += $grandChildren[0]
            $child.parameters = $flatParameters
            $child.scope = @{
                $pacSelector = $allScopes.ToArray()
            }
            if ($allNotScopes.Count -gt 0) {
                $child.notScope = @{
                    $pacSelector = $allNotScopes.ToArray()
                }
            }
        }
        else {
            # complete grandChildren with scope
            $count = $grandChildren.Count
            for ($i = 0; $i -lt $count; $i++) {
                $grandChild = $grandChildren[$i]
                $grandChildScope = $grandChildScopes[$i]
                $grandChildScopeArray = $grandChildScope.scopes
                $grandChild.scope = @{
                    $pacSelector = $grandChildScopeArray
                }
                $notScopes = $grandChildScope.notScopes
                if ($notScopes.Count -gt 0) {
                    $grandChild.notScope = @{
                        $pacSelector = $notScopes
                    }
                }
            }
            $child = [ordered]@{
                nodeName   = "/parameters-$($children.Count + 1)"
                parameters = $flatParameters
                children   = $grandChildren.ToArray()
            }
        }
        $null = $children.Add($child)
    }

    # Check is we can flatten the tree more
    if ($children.Count -eq 1) {
        # Only one parameter cluster, flatten structure
        $childZero = $children[0]
        $childZero.Remove("nodeName")
        $assignmentDefinition += $childZero
    }
    else {
        $assignmentDefinition.children = $children.ToArray()
    }

    # Write structure to file
    $json = ConvertTo-Json $assignmentDefinition -Depth 100
    $null = New-Item $fullPath -Force -ItemType File -Value $json

}
