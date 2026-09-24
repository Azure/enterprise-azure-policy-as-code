function Get-PolicySetVersionedDetails {
    <#
    .SYNOPSIS
    Resolves a Policy Set assignment's definitionVersion to a concrete published version and returns
    the member details and required roleDefinitionIds for that version.

    .DESCRIPTION
    EPAC reads deployed Policy Set definitions at their latest version. An assignment which pins
    definitionVersion runs a different version, whose member list and hard-coded member effects can
    differ. Calculating the Managed Identity roles from the latest version therefore grants the wrong
    roles: roles can be missing for members which only deploy in the pinned version.

    This resolves the pinned version from the Policy Set's published version history and recomputes
    both the member details and the role union against it.

    Resolution follows the wildcard forms EPAC's assignment schema allows, 'XX.*.*' and 'XX.XX.*', and
    also accepts an exact version. Stable versions are preferred; a pre-release version is only
    selected when no stable version matches the requested pattern.

    Any failure to resolve - no version history, an unmatched pattern or a REST error - returns $null
    so the caller falls back to the latest definition and its unfiltered roles.

    .PARAMETER PolicySetId
    Resource id of the Policy Set definition.

    .PARAMETER DefinitionVersion
    The version or version wildcard pinned by the assignment.

    .PARAMETER PacEnvironment
    The pacEnvironment, used for the policySetDefinitionVersions API version.

    .PARAMETER PolicyDetails
    Policy details hashtable keyed by Policy definition id, as produced by Convert-PolicyResourcesToDetails.

    .PARAMETER PolicyRoleIds
    Hashtable of definition id to roleDefinitionIds, used to build the member role union.

    .PARAMETER Cache
    Hashtable used to memoize version history lookups across assignments in one build.

    .OUTPUTS
    Hashtable with policySetDetails, policyRoleDefinitionIds and resolvedVersion, or $null.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $PolicySetId,

        [Parameter(Mandatory = $true)]
        [string] $DefinitionVersion,

        [Parameter(Mandatory = $true)]
        $PacEnvironment,

        [Parameter(Mandatory = $true)]
        [hashtable] $PolicyDetails,

        [Parameter(Mandatory = $true)]
        $PolicyRoleIds,

        [Parameter(Mandatory = $false)]
        [hashtable] $Cache = $null
    )

    #region retrieve version history

    $versions = $null
    if ($null -ne $Cache -and $Cache.ContainsKey($PolicySetId)) {
        $versions = $Cache.$PolicySetId
    }
    else {
        $apiVersion = $PacEnvironment.apiVersions.policySetDefinitionVersions
        if (-not $apiVersion) {
            $apiVersion = $PacEnvironment.apiVersions.policySetDefinitions
        }
        $versions = Get-AzPolicySetDefinitionVersionsRestMethod -PolicySetId $PolicySetId -ApiVersion $apiVersion
        if ($null -ne $Cache) {
            $Cache[$PolicySetId] = $versions
        }
    }

    if ($null -eq $versions -or @($versions).Count -eq 0) {
        return $null
    }

    #endregion retrieve version history

    #region resolve the requested version

    # A pattern may carry a pre-release suffix, for example '1.*.*-preview', which opts the
    # assignment in to pre-release versions of the matching line.
    $pattern = $DefinitionVersion
    $preReleaseRequested = $false
    $patternDashIndex = $pattern.IndexOf("-")
    if ($patternDashIndex -ge 0) {
        $pattern = $pattern.Substring(0, $patternDashIndex)
        $preReleaseRequested = $true
    }

    $patternSegments = $pattern.Split(".")
    $stableMatches = [System.Collections.ArrayList]::new()
    $preReleaseMatches = [System.Collections.ArrayList]::new()

    foreach ($candidate in $versions) {
        $name = $candidate.name
        if (-not $name) {
            continue
        }

        # Split '1.3.0-preview' into the numeric core '1.3.0' and the pre-release label 'preview'.
        $core = $name
        $isPreRelease = $false
        $dashIndex = $name.IndexOf("-")
        if ($dashIndex -ge 0) {
            $core = $name.Substring(0, $dashIndex)
            $isPreRelease = $true
        }

        $coreSegments = $core.Split(".")
        if ($coreSegments.Count -ne $patternSegments.Count) {
            continue
        }

        $isMatch = $true
        for ($i = 0; $i -lt $patternSegments.Count; $i++) {
            if ($patternSegments[$i] -eq "*") {
                continue
            }
            if ($patternSegments[$i] -ne $coreSegments[$i]) {
                $isMatch = $false
                break
            }
        }
        if (-not $isMatch) {
            continue
        }

        $sortableVersion = $null
        if (-not [System.Version]::TryParse($core, [ref] $sortableVersion)) {
            continue
        }

        $entry = @{
            definition   = $candidate
            version      = $sortableVersion
            name         = $name
            isPreRelease = $isPreRelease
        }
        if ($isPreRelease) {
            $null = $preReleaseMatches.Add($entry)
        }
        else {
            $null = $stableMatches.Add($entry)
        }
    }

    # A pre-release is only used when the requested pattern matches nothing stable, unless the
    # pattern explicitly asked for pre-releases.
    $candidates = $stableMatches
    if ($preReleaseRequested) {
        $candidates = [System.Collections.ArrayList]::new()
        $candidates.AddRange($stableMatches)
        $candidates.AddRange($preReleaseMatches)
    }
    if ($candidates.Count -eq 0) {
        $candidates = $preReleaseMatches
    }
    if ($candidates.Count -eq 0) {
        Write-Verbose "No published version of '$PolicySetId' matches definitionVersion '$DefinitionVersion'"
        return $null
    }

    # Ties between a stable and a pre-release of the same core version favour the pre-release only
    # when the pattern asked for one.
    $resolved = $candidates |
        Sort-Object -Property @{ Expression = { $_.version } }, @{ Expression = { $_.isPreRelease -eq $preReleaseRequested } } -Descending |
        Select-Object -First 1

    #endregion resolve the requested version

    #region calculate details and roles for the resolved version

    $versionedDetails = @{}
    Convert-PolicySetToDetails `
        -PolicySetId $PolicySetId `
        -PolicySetDefinition $resolved.definition `
        -PolicySetDetails $versionedDetails `
        -PolicyDetails $PolicyDetails

    $policySetDetails = $versionedDetails.$PolicySetId
    if ($null -eq $policySetDetails) {
        return $null
    }

    # Union the roles of the members present in this version, matching how Build-DeploymentPlans
    # calculates the role union for the latest version.
    $roleIds = [ordered]@{}
    $properties = Get-PolicyResourceProperties -PolicyResource $resolved.definition
    foreach ($policyInPolicySet in $properties.policyDefinitions) {
        $policyId = $policyInPolicySet.policyDefinitionId
        if ($PolicyRoleIds.ContainsKey($policyId)) {
            foreach ($roleDefinitionId in $PolicyRoleIds.$policyId) {
                $roleIds[$roleDefinitionId] = "added"
            }
        }
    }

    return @{
        policySetDetails        = $policySetDetails
        policyRoleDefinitionIds = @($roleIds.Keys)
        resolvedVersion         = $resolved.name
    }

    #endregion calculate details and roles for the resolved version
}
