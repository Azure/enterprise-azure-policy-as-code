#Requires -PSEdition Core

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $outputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Switch to include Policies and Policy Sets definitions in child scopes")]
    [switch] $includeChildScopes,

    [Parameter(Mandatory = $false, HelpMessage = "Switch to output Exemptions as JSON (instead of CSV).")]
    [switch] $exemptionsAsJson,

    [ValidateSet("json", "jsonc")]
    [Parameter(Mandatory = $false, HelpMessage = "File extension type for the output files. Defaults to '.jsonc'.")]
    [string] $fileExtension = "jsonc"
)

function ConvertTo-ArrayList {
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        $InputObject = $null,

        [switch] $skipNull
    )

    $list = [System.Collections.ArrayList]::new()
    if ($null -ne $InputObject -or !$skipNull) {
        $null = $list.Add($InputObject)
    }
    return $list
}

function Set-CollapsedCluster1 {
    param (
        [hashtable] $parentNode,
        [string[]] $propertyNames,
        [int] $currentIndex,
        [hashtable] $collapsedTree = @{}
    )

    $propertyName = $propertyNames[$currentIndex]
    $parentNodeClusters = $parentNode.clusters
    foreach ($key in $parentNodeClusters.Keys) {
        $clusters = $parentNodeClusters.$key
        if ($clusters.count -eq 1) {
            $parentNode.$key = $clusters[0]
            $collapsedTree[$propertyName] = $true
        }
    }

    $currentIndex++
    foreach

}

function Set-ClusterAncestors {
    param (
        [hashtable] $parentNode,
        [string[]] $propertyNames,
        [int] $currentIndex
    )

    $propertyName = $propertyNames[$currentIndex]

    # update all ancestors
    if ($propertyName -ne "scopeEx") {
        $currentParent = $parentNode.parent
        while ($null -ne $currentParent) {
            $found = Merge-Cluster -node $currentParent -property $property
            if ($found) {
                break
            }
            $currentParent = $currentParentNode.parent
        }
    }

    # recursively call Set-ClusterNode to process remaining descendants
    $currentIndex++
    if ($currentIndex -lt ($propertyNames.Count - 1)) {
        next cluster s down
        if (one) {
        }
        foreach ()
        Set-ClustersGrandParentNodes -parentNode $thisNode -propertyNames $propertyNames -propertiesList $propertiesList -currentIndex $currentIndex
    }
}

function Set-ClustersNode {
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string[]] $propertyNames,
        [hashtable] $propertiesList,
        [int] $currentIndex
    )

    $propertyName = $propertyNames[$currentIndex]
    $propertyValue = $property.$propertyName

    # process this list entry
    $thisNode = Merge-Child `
        -parentNode $parentNode `
        -pacSelector $pacSelector `
        -propertyName $propertyName `
        -propertyValue $propertyValue

    # recursively call Set-ClusterNode to create remaining descendants
    $currentIndex++
    if ($currentIndex -lt $nameValuePairList.Count) {
        Set-ClustersNode `
            -parentNode $thisNode `
            -pacSelector $pacSelector `
            -propertyNames $propertyNames `
            -propertiesList $propertiesList `
            -currentIndex $currentIndex
    }
}

function New-ExportNode {
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string] $propertyName,
        $propertyValue
    )

    $propertyValueModified = $propertyValue
    if ($propertyName -in @( "locationEx", "identityEx" )) {
        $propertyValueModified = @{
            $pacSelector = $propertyValue
        }
    }
    elseif ($propertyName -eq "scopeEx") {
        $propertyValueModified = @{
            $pacSelector = ConvertTo-ArrayList($propertyValue)
        }
    }

    $node = @{
        $propertyName = $propertyValueModified
        parent        = $parentNode
        children      = [System.Collections.ArrayList]::new()
        clusters      = @{}
    }

    return $node
}

function Merge-Child {
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string] $propertyName,
        $propertyValue
    )

    $parentChildren = $parentNode.children
    foreach ($child in $parentChildren) {
        $match = $false
        $childPropertyValue = $child.$propertyName
        switch ($propertyName) {
            parametersEx {
                $match = Confirm-AssignmentParametersMatch -existingParametersObj $childPropertyValue -definedParametersObj $propertyValue -compareTwoExistingParametersObj
                break
            }
            enforcementMode {
                $match = $childPropertyValue -eq $propertyValue
                break
            }
            locationEx {
                if ($childPropertyValue.ContainsKey($pacSelector)) {
                    $match = $propertyValue -eq $childPropertyValue.$pacSelector
                }
                break
            }
            identityEx {
                if ($childPropertyValue.ContainsKey($pacSelector)) {
                    $match = $propertyValue -eq $childPropertyValue.$pacSelector
                }
                break
            }
            identityEx {
                if ($childPropertyValue.ContainsKey($pacSelector)) {
                    $match = $true
                    $list = $childPropertyValue.$pacSelector
                    $null = $list.Add($propertyValue)
                }
                break
            }
            default {
                $match = Confirm-ObjectValueEqualityDeep -existingObj $cluster.overrides -definedObj $propertyValue
                break
            }
        }
        if ($match) {
            # existing cluster
            return $child
        }
    }

    $child = New-ExportNode `
        -parentNode $parentNode `
        -pacSelector $pacSelector `
        -propertyName $propertyName `
        -propertyValue $propertyValue
    $null = $parentChildren.Add($child)

    return $child
}

function Merge-AncestorCluster {
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string] $propertyName,
        $propertyValue
    )

    $parentClusters = $parentNode.clusters
    if (-not $parentClusters.ContainsKey($propertyName)) {
        $null = $parentClusters.Add($propertyName, [System.Collections.ArrayList]::new())
    }
    $parentCluster = $parentClusters.$propertyName

    $foundCluster = $null
    :loop foreach ($cluster in $parentCluster) {
        $match = $false
        $clusterPropertyValue = $cluster.propertyValue
        switch ($propertyName) {
            parametersEx {
                $match = Confirm-AssignmentParametersMatch -existingParametersObj $clusterPropertyValue -definedParametersObj $propertyValue -compareTwoExistingParametersObj
                break
            }
            enforcementMode {
                $match = $clusterPropertyValue -eq $propertyValue
                break
            }
            identityEx {
                $foundCluster = $cluster
                if ($clusterPropertyValue.ContainsKey($pacSelector)) {
                    $perPacArray = $clusterPropertyValue.$pacSelector
                    $null = $perPacArray.Add($propertyValue)
                }
                else {
                    $null = $clusterPropertyValue.Add($pacSelector, (ConvertTo-ArrayList $propertyValue))
                }
                break loop
            }
            scopeCollection {
                $foundCluster = $cluster
                if ($clusterPropertyValue.ContainsKey($pacSelector)) {
                    $perPacArray = $clusterPropertyValue.$pacSelector
                    $null = $perPacArray.Add($propertyValue)
                }
                else {
                    $null = $clusterPropertyValue.Add($pacSelector, (ConvertTo-ArrayList $propertyValue))
                }
                break loop
            }
            default {
                $match = Confirm-ObjectValueEqualityDeep -existingObj $cluster.overrides -definedObj $propertyValue
                break
            }
        }
        if ($match) {
            # Add to existing cluster
            $foundCluster = $cluster
            break
        }
    }

    if ($null -ne $foundCluster) {
        if ($processDirectParent) {
            return $foundCluster
        }
        else {
            return $true
        }
    }
    else {
        $cluster = @{
            $propertyName = $propertyValue
        }
        if ($propertyName -eq "identityEx" -or $propertyNam -eq "scopeEx") {
            $cluster.$propertyName = @{
                $pacSelector = ConvertTo-ArrayList $propertyValue
            }
        }
        $null = $parentClusterList.Add($cluster)
        if ($processDirectParent) {
            $cluster.clusters = @{}
            $cluster["parent"] = $parentNode
            return $cluster
        }
        else {
            $cluster["parent"] = $null
            return $false
        }
    }
}
# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

#region Initialize

$InformationPreference = "Continue"
$globalSettings = Get-GlobalSettings -definitionsRootFolder $definitionsRootFolder -outputFolder $outputFolder -inputFolder $inputFolder
$pacEnvironments = $globalSettings.pacEnvironments
$outputFolder = $globalSettings.outputFolder
$definitionsFolder = "$($outputFolder)/Definitions"
$policyDefinitionsFolder = "$definitionsFolder/policyDefinitions"
$policySetDefinitionsFolder = "$definitionsFolder/policySetDefinitions"
$policyAssignmentsFolder = "$definitionsFolder/policyAssignments"
$invalidChars = [IO.Path]::GetInvalidFileNameChars()
$invalidChars += ("[]()$".ToCharArray())
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

Write-Information "==================================================================================================="
Write-Information "Exporting Policy resources"
Write-Information "==================================================================================================="
Write-Information "WARNING! This script assumes the following:"
Write-Information "* Names of Policies and Policy Sets with the same name define the same properties independent of scope and EPAC environment."
Write-Information "* Assignment names are the same if the parameters match across multiple assignments across scopes."
Write-Information "* Ignores Assignments auto-assigned by Security Center."
Write-Information ""
Write-Information "Notes on Assignments:"
Write-Information "* Does not calculate any additionalRoleAssignments."
Write-Information "* Creates a tree with three (3) levels:"
Write-Information "  * Parent: definitionEntry with (optional) complianceMessages"
Write-Information "  * Children: parameters, (optional) overrides, (optional) resourceSelectors"
Write-Information "  * Grandchildren: assignment definition (name, displayName, description, enforcementMode), scopes, (optional) notScopes, (optional) user-assigned identity"
Write-Information "* Optimizes (collapses)"
Write-Information "  * Grandchildren differing only in scope/notScope into child"
Write-Information "  * Single child into parent"
Write-Information "==================================================================================================="

$policyPropertiesByName = @{}
$policySetPropertiesByName = @{}
$assignmentsByPolicyDefinition = @{}

$propertyNames = @(
    "parametersEx", # parameters, overrides, resourceSelectors
    "nonComplianceMessages",
    "nameEx", # name, displayName, description and metadata, equality by name only
    "locationEx" # by pac: location
    "identityEx", # by pac: $null or string for userAssignedIdentity
    "scopeEx" # by pac: scope with array of notScopes
)

#endregion Initialize

foreach ($pacEnvironment in $pacEnvironments.Values) {

    #region retrieve Policy resources

    $pacSelector = $pacEnvironment.pacSelector
    Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $interactive

    $globalNotScopesList = [System.Collections.ArrayList]::new()
    foreach ($notScope in $pacEnvironment.globalNotScopes) {
        if (!($notScope.StartsWith("/resourceGroupPatterns/"))) {
            $null = $globalNotScopesList.Add($notScope)
        }
    }
    $globalNotScopes = $globalNotScopesList |  Sort-Object | Get-Unique

    $scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
    $deployed = Get-AzPolicyResources -pacEnvironment $pacEnvironment -scopeTable $scopeTable -skipRoleAssignments -skipExemptions -collectAllPolicies:$includeChildScopes

    $policyDefinitions = $deployed.policydefinitions.custom
    $policySetDefinitions = $deployed.policysetdefinitions.custom
    $policyAssignments = $deployed.policyassignments.all
    $allDefinitions = @{}

    #endregion retrieve Policy resources

    #region Policy definitions

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Processing $($policyDefinitions.Count) Policies in EPAC environment $pacSelector"
    Write-Information "==================================================================================================="

    foreach ($policyDefinition in $policyDefinitions.Values) {
        $properties = Get-PolicyResourceProperties -policyResource $policyDefinition
        $metadata = Get-CustomMetadata $properties.metadata -remove "pacOwnerId"
        $version = $properties.version
        $id = $policyDefinition.id
        $name = $policyDefinition.name
        if ($null -eq $version) {
            if ($metadata.version) {
                $version = $metadata.version
            }
            else {
                $version = 1.0.0
            }
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
        Out-PolicyDefinition `
            -definition $definition `
            -folder $policyDefinitionsFolder `
            -policyPropertiesByName $policyPropertiesByName `
            -invalidChars $invalidChars `
            -typeString "Policy" `
            -id $id `
            -fileExtension $fileExtension
    }

    #endregion Policy definitions

    #region Policy Set definitions

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Processing $($policySetDefinitions.Count) Policy Sets in EPAC environment $pacSelector"
    Write-Information "==================================================================================================="

    foreach ($policySetDefinition in $policySetDefinitions.Values) {
        $properties = Get-PolicyResourceProperties -policyResource $policySetDefinition
        $metadata = Get-CustomMetadata $properties.metadata -remove "pacOwnerId"
        $version = $properties.version
        if ($null -eq $version) {
            if ($metadata.version) {
                $version = $metadata.version
            }
            else {
                $version = 1.0.0
            }
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
        Out-PolicyDefinition `
            -definition $definition `
            -folder $policySetDefinitionsFolder `
            -policyPropertiesByName $policySetPropertiesByName `
            -invalidChars $invalidChars `
            -typeString "Policy" `
            -id $policySetDefinition.id `
            -fileExtension $fileExtension
    }

    #endregion Policy Set definitions

    #region collate multiple entries by policyDefinitionId and than by scope and also parameters

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Collating $($policyAssignments.Count) Policy Assignments in EPAC environment $pacSelector"
    Write-Information "==================================================================================================="

    foreach ($policyAssignment in $policyAssignments.Values) {
        $id = $policyAssignment.id
        if ($id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/ASC-*" -or $id -like "/subscriptions/*/providers/Microsoft.Authorization/policyAssignments/SecurityCenterBuiltIn") {
            Write-Warning "Do not process Security Center: $id"
        }
        else {
            $properties = Get-PolicyResourceProperties -policyResource $policyAssignment
            $metadata = Get-CustomMetadata $properties.metadata -remove "pacOwnerId,roles"

            $name = $policyAssignment.name
            $policyDefinitionId = $properties.policyDefinitionId
            $parts = Split-AzPolicyResourceId -id $policyDefinitionId
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
            if ($null -ne $properties.description -and $properties.description -ne "") {
                $description = $properties.description
            }
            $assignmentName = @{
                name        = $name
                displayName = $displayName
                description = $description
            }

            $scope = $policyAssignment.resourceIdParts.scope
            $notScopes = $policyAssignment.notScopes
            $scopeCollection = @{
                $pacSelector = @{
                    scope     = $scope
                    notScopes = $notScopes
                }
            }

            $identityCollection = @{
                $pacSelector = $properties.identity
            }

            $parameters = @{}
            if ($null -ne $properties.parameters -and $properties.parameters.Count -gt 0) {
                $parameters = Get-DeepClone $properties.parameters -AsHashTable
            }
            $overrides = $properties.overrides
            $resourceSelectors = $properties.resourceSelectors

            $nonComplianceMessages = $null
            if ($properties.nonComplianceMessages -and $properties.nonComplianceMessages.Count -gt 0) {
                $nonComplianceMessages = $properties.nonComplianceMessages
            }

            $perDefinition = $null
            $policyAssignmentEx = @{
                pacSelector = $pacSelector
                assignment  = $policyAssignment
            }

            $propertiesList = @{
                parameters            = $parameters
                overrides             = $overrides
                resourceSelectors     = $resourceSelectors
                enforcementMode       = $enforcementMode
                nonComplianceMessages = $nonComplianceMessages
                metadata              = $metadata
                identityCollection    = $identityCollection
                scopeCollection       = $scopeCollection
                assignmentName        = $assignmentName
            }

            $perDefinition = $null
            if (-not $assignmentsByPolicyDefinition.ContainsKey($policyDefinitionKey)) {
                $perDefinition = @{
                    parent          = $null
                    clusters        = @{}
                    definitionEntry = @{
                        definitionKey = $policyDefinitionKey
                        id            = $parts.id
                        name          = $parts.name
                        displayName   = $definitionDisplayName
                        scope         = $parts.scope
                        scopeType     = $parts.scopeType
                        kind          = $parts.kind
                        isBuiltin     = $parts.scopeType -eq "builtin"
                    }
                }
            }
            else {
                $perDefinition = $assignmentsByPolicyDefinition.$policyDefinitionKey
            }
            Set-ClustersNode -parentNode $perDefinition -propertyNames $propertyNames -propertiesList $propertiesList -currentIndex 0

        }
    }
}

#endregion collate multiple entries by policyDefinitionId and than by scope and also parameters

#region create assignment files (one per definition id), use clusters to collapse tree

foreach ($policyDefinitionKey in $assignmentsByPolicyDefinition.Keys) {
    $perDefinition = $assignmentsByPolicyDefinition.$policyDefinitionKey
    $definition = $perDefinition.definitionEntry
    $definitionKind = $definition.kind
    $definitionName = $definition.name
    $definitionId = $definition.id
    $definitionDisplayName = $definition.displayName

    $subfolder = $definitionKind -replace "Definitions", ""
    $fullPath = Get-DefinitionsFullPath `
        -folder $policyAssignmentsFolder `
        -rawSubFolder $subFolder `
        -name $definition.name `
        -displayName $definitionDisplayName `
        -invalidChars $invalidChars `
        -maxLengthSubFolder 30 `
        -maxLengthFileName 100

    # Create definitionEntry
    $definitionEntry = @{}
    if ($definition.isBuiltin) {
        if ($definitionKind -eq "policySetDefinitions") {
            $definitionEntry = @{
                policySetId = $definitionId
                displayName = $definitionDisplayName
            }
        }
        else {
            $definitionEntry = @{
                policyId    = $definitionId
                displayName = $definitionDisplayName
            }
        }
    }
    else {
        # Custom
        $definition = $allDefinitions[$policyDefinitionKey]
        if ($perDefinition.definitionKind -eq "policySetDefinitions") {
            $definitionEntry = @{
                policySetName = $definitionName
                displayName   = $definitionDisplayName
            }
        }
        else {
            $definitionEntry = @{
                policyName  = $definitionName
                displayName = $definitionDisplayName
            }
        }
    }

    $assignmentDefinition = [ordered]@{
        nodeName        = "/root"
        definitionEntry = $definitionEntry
    }
    $children = [System.Collections.ArrayList]::new()
    foreach ($parameterCluster in $perDefinition.parameterClusters) {

        $parameterSet = $parameterCluster.clusterParameters
        $flatParameters = @{}
        foreach ($parameterName in $parameterSet.Keys) {
            $flatParameters[$parameterName] = ($parameterSet[$parameterName]).value
        }
        $overrides = $parameterCluster.clusterOverrides
        $resourceSelectors = $parameterCluster.clusterResourceSelectors

        $child = [ordered]@{}
        $grandChildren = [System.Collections.ArrayList]::new()
        $grandChildScopes = [System.Collections.ArrayList]::new()
        $allScopes = [System.Collections.ArrayList]::new()
        $allNotScopes = [System.Collections.ArrayList]::new()
        $allNotScopeProcessed = @{}
        $assignmentEx = $parameterCluster.assignmentsEx
        foreach ($id in $assignmentEx.Keys) {
            $currentAssignment = $assignmentEx.$id
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
                        $null = $notScopes.Add($notScope)
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

#endregion create assignment files (one per definition id), use clusters to collapse tree
