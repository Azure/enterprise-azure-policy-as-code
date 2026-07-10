function Get-AzPolicySetDefinitionVersions {
    <#
    .SYNOPSIS
        Collects version-specific Policy Set definitions referenced by pinned assignment versions.

    .DESCRIPTION
        Deployed Policy Assignments can pin a specific initiative (Policy Set) version via the
        'definitionVersion' property (for example '1.3.*-preview'). The default Resource Graph
        query only returns the current/latest version of each Policy Set definition; older,
        version-specific definitions are stored in a separate Resource Graph table
        (microsoft.authorization/policysetdefinitions/versions).

        This function inspects the deployed assignments for pinned Policy Set versions, and for
        each referenced initiative retrieves the matching version resource from Resource Graph.
        Results are stored in $PolicySetDefinitionsTable.versions keyed by "<policySetId>||<version>".

        Only versions that are actually referenced by a pinned assignment are collected. Pins that
        resolve to the already collected latest version are skipped to avoid unnecessary queries.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $PacEnvironment,

        [Parameter(Mandatory = $true)]
        [hashtable] $PolicySetDefinitionsTable,

        [Parameter(Mandatory = $true)]
        [hashtable] $PolicyAssignments
    )

    if ($null -eq $PolicySetDefinitionsTable.versions) {
        $PolicySetDefinitionsTable.versions = @{}
    }

    #region determine pinned Policy Set versions referenced by deployed assignments
    $pinnedVersionsByPolicySetId = @{}
    foreach ($assignment in $PolicyAssignments.Values) {
        $properties = Get-PolicyResourceProperties -PolicyResource $assignment
        $assignedDefinitionId = $properties.policyDefinitionId
        if ([string]::IsNullOrWhiteSpace($assignedDefinitionId)) {
            continue
        }
        if (-not $assignedDefinitionId.Contains("/providers/Microsoft.Authorization/policySetDefinitions/", [System.StringComparison]::InvariantCultureIgnoreCase)) {
            continue
        }

        $pinnedVersion = $properties.definitionVersion
        if ([string]::IsNullOrWhiteSpace($pinnedVersion)) {
            $pinnedVersion = $properties.effectiveDefinitionVersion
        }
        if ([string]::IsNullOrWhiteSpace($pinnedVersion)) {
            continue
        }

        # Skip pins that already match the latest collected version - no separate version needed
        $latestPolicySet = $PolicySetDefinitionsTable.all[$assignedDefinitionId]
        if ($null -ne $latestPolicySet) {
            $latestVersion = (Get-PolicyResourceProperties -PolicyResource $latestPolicySet).version
            if (-not [string]::IsNullOrWhiteSpace($latestVersion) -and (Compare-SemanticVersion -Version1 $latestVersion -Version2 $pinnedVersion) -eq 0) {
                continue
            }
        }

        if (-not $pinnedVersionsByPolicySetId.ContainsKey($assignedDefinitionId)) {
            $pinnedVersionsByPolicySetId[$assignedDefinitionId] = @{}
        }
        $pinnedVersionsByPolicySetId[$assignedDefinitionId][$pinnedVersion] = $true
    }

    if ($pinnedVersionsByPolicySetId.Count -eq 0) {
        return
    }
    #endregion determine pinned Policy Set versions referenced by deployed assignments

    #region query Resource Graph for the referenced Policy Set definition versions
    $baseIds = @($pinnedVersionsByPolicySetId.Keys)
    $filterClauses = $baseIds | ForEach-Object { "id startswith '$_/versions/'" }
    $filter = $filterClauses -join " or "
    $query = "PolicyResources | where type == 'microsoft.authorization/policysetdefinitions/versions' | where $filter"

    $versionResources = Search-AzGraphAllItems `
        -Query $query `
        -ProgressItemName "Policy Set definition versions" `
        -ProgressIncrement 250
    #endregion query Resource Graph for the referenced Policy Set definition versions

    #region group the returned version resources by base Policy Set id
    $environmentTenantId = $PacEnvironment.tenantId
    $versionResourcesByBaseId = @{}
    foreach ($versionResource in $versionResources) {
        $resourceTenantId = $versionResource.tenantId
        if (-not (($resourceTenantId -in @($null, "", $environmentTenantId)) -or $null -ne $PacEnvironment.managedTenantId)) {
            continue
        }
        $versionResourceId = $versionResource.id
        $splitIndex = $versionResourceId.IndexOf("/versions/", [System.StringComparison]::InvariantCultureIgnoreCase)
        if ($splitIndex -lt 0) {
            continue
        }
        $baseId = $versionResourceId.Substring(0, $splitIndex)
        $versionString = $versionResourceId.Substring($splitIndex + "/versions/".Length)
        $properties = Get-PolicyResourceProperties -PolicyResource $versionResource
        if (-not [string]::IsNullOrWhiteSpace($properties.version)) {
            $versionString = $properties.version
        }

        # Normalize so downstream detail conversion behaves like a regular Policy Set definition
        $versionResource.id = $baseId
        $versionResource.version = $versionString

        if (-not $versionResourcesByBaseId.ContainsKey($baseId)) {
            $versionResourcesByBaseId[$baseId] = [System.Collections.ArrayList]::new()
        }
        $null = $versionResourcesByBaseId[$baseId].Add($versionResource)
    }
    #endregion group the returned version resources by base Policy Set id

    #region resolve each pin to the best matching concrete version and store it
    foreach ($baseId in $pinnedVersionsByPolicySetId.Keys) {
        if (-not $versionResourcesByBaseId.ContainsKey($baseId)) {
            Write-ModernStatus -Message "No Policy Set definition versions found in Azure for '$baseId'" -Status "warning" -Indent 4
            continue
        }
        $availableVersionResources = $versionResourcesByBaseId[$baseId]
        $availableVersions = @($availableVersionResources | ForEach-Object { $_.version })

        foreach ($pinnedVersion in $pinnedVersionsByPolicySetId[$baseId].Keys) {
            $matchedVersion = Get-BestMatchingVersion -PinnedVersion $pinnedVersion -AvailableVersions $availableVersions
            if ($null -eq $matchedVersion) {
                Write-ModernStatus -Message "No Policy Set version matching '$pinnedVersion' found for '$baseId'" -Status "warning" -Indent 4
                continue
            }
            $matchedResource = $availableVersionResources | Where-Object { $_.version -eq $matchedVersion } | Select-Object -First 1
            $key = "$baseId||$matchedVersion"
            if (-not $PolicySetDefinitionsTable.versions.ContainsKey($key)) {
                $null = $PolicySetDefinitionsTable.versions.Add($key, $matchedResource)
            }
        }
    }
    #endregion resolve each pin to the best matching concrete version and store it
}
