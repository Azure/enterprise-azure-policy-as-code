function Get-BuiltInVersionStatus {
    <#
    .SYNOPSIS
    Determines the definition version status of a single assignment against the latest published
    version of the built-in Policy or Policy Set definition it references.

    .DESCRIPTION
    Azure pins an assignment to a major version whether or not the EPAC definition files ask for it.
    When an assignment is created without definitionVersion, Azure stamps '{latestMajor}.*.*' server
    side, so the assignment silently follows minor and patch updates but never moves to a new major
    version. An assignment can therefore fall behind a major version without EPAC reporting any drift,
    because the pinned version still matches what is deployed.

    This evaluates every assignment, not only the ones which pin a version in the definition files. The
    effective version is resolved in this order:

      1. definitionVersion from the assignment definition files.
      2. definitionVersion stamped on the deployed assignment by Azure.
      3. Nothing, which means the assignment is new and will be stamped with the latest major version
         when it is created.

    The latest version is read from the definition already loaded by EPAC, so no extra Azure calls are
    made. Azure also exposes effectiveDefinitionVersion and latestDefinitionVersion, but only through
    an ARM $expand on a per assignment GET, which Azure Resource Graph does not return and which would
    cost one REST call per assignment.

    Only major versions are compared. Minor and patch updates are ingested automatically by the
    wildcard Azure applies, so reporting them would be noise.

    .PARAMETER PolicyDefinitionId
    Resource id of the Policy or Policy Set definition referenced by the assignment.

    .PARAMETER DefinitionVersion
    The version pinned by the assignment definition files, if any.

    .PARAMETER DeployedDefinitionVersion
    The definitionVersion stamped on the deployed assignment, if the assignment already exists.

    .PARAMETER PolicyDefinition
    The latest definition object as loaded by EPAC, used to read policyType and the published version.

    .OUTPUTS
    Hashtable describing the version status. The status field is one of:
      updateAvailable - a newer major version of the built-in is published
      current         - the assignment is on the latest major version
      tracksLatest    - no version is pinned yet, so the assignment will take the latest major version
      custom          - the definition is not a built-in, so EPAC versions it in the repo
      unknown         - the version could not be determined and no advisory can be given
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $PolicyDefinitionId,

        [Parameter(Mandatory = $false)]
        [string] $DefinitionVersion,

        [Parameter(Mandatory = $false)]
        [string] $DeployedDefinitionVersion,

        [Parameter(Mandatory = $false)]
        $PolicyDefinition
    )

    $status = @{
        policyDefinitionId = $PolicyDefinitionId
        displayName        = $null
        status             = "unknown"
        updateAvailable    = $false
        assignedVersion    = $null
        assignedMajor      = $null
        assignedVersionFrom = "none"
        latestVersion      = $null
        latestMajor        = $null
    }

    if ($null -eq $PolicyDefinition) {
        # The referenced definition was not loaded, so nothing can be said about its version
        return $status
    }

    $properties = Get-PolicyResourceProperties -PolicyResource $PolicyDefinition

    $displayName = $properties.displayName
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        $displayName = $PolicyDefinition.name
    }
    $status.displayName = $displayName

    if ($properties.policyType -ne "BuiltIn") {
        # Custom definitions are versioned by the EPAC repo itself
        $status.status = "custom"
        return $status
    }

    $latestVersion = $properties.version
    if ([string]::IsNullOrWhiteSpace($latestVersion) -and $properties.metadata) {
        $latestVersion = $properties.metadata.version
    }
    $latestMajor = Get-MajorVersionNumber -Version $latestVersion
    $status.latestVersion = $latestVersion
    $status.latestMajor = $latestMajor

    # Resolve the version the assignment actually runs: the definition files win, then whatever
    # Azure stamped on the deployed assignment.
    $assignedVersion = $null
    $assignedVersionFrom = "none"
    if (-not [string]::IsNullOrWhiteSpace($DefinitionVersion)) {
        $assignedVersion = $DefinitionVersion
        $assignedVersionFrom = "assignmentFile"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($DeployedDefinitionVersion)) {
        $assignedVersion = $DeployedDefinitionVersion
        $assignedVersionFrom = "deployed"
    }
    $status.assignedVersion = $assignedVersion
    $status.assignedVersionFrom = $assignedVersionFrom

    if ($null -eq $latestMajor) {
        # The built-in publishes no usable version, so no comparison is possible
        return $status
    }

    $assignedMajor = Get-MajorVersionNumber -Version $assignedVersion
    $status.assignedMajor = $assignedMajor

    if ($null -eq $assignedMajor) {
        # No pinned version, or a wildcard major: Azure applies the latest major version
        $status.status = "tracksLatest"
        return $status
    }

    if ($latestMajor -gt $assignedMajor) {
        $status.status = "updateAvailable"
        $status.updateAvailable = $true
    }
    else {
        $status.status = "current"
    }
    return $status
}

function Get-MajorVersionNumber {
    <#
    .SYNOPSIS
    Returns the major version number of a version string or wildcard, or $null when it cannot be determined.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $Version
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        return $null
    }

    # Strip a pre-release suffix such as '-preview' before reading the numeric core
    $core = $Version
    $dashIndex = $core.IndexOf("-")
    if ($dashIndex -ge 0) {
        $core = $core.Substring(0, $dashIndex)
    }

    $major = $core.Split(".")[0]
    $majorNumber = 0
    if (-not [int]::TryParse($major, [ref] $majorNumber)) {
        # A wildcard major, for example '*.*.*', always follows the latest version
        return $null
    }
    return $majorNumber
}
