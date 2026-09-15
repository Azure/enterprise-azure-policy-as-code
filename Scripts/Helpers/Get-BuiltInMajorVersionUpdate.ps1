function Get-BuiltInMajorVersionUpdate {
    <#
    .SYNOPSIS
    Detects whether a newer major version of a built-in Policy or Policy Set definition is available
    for the version pinned by an assignment.

    .DESCRIPTION
    An assignment which pins definitionVersion, for example '1.*.*', stays on that major version line
    forever. When Microsoft publishes a new major version of the built-in definition, EPAC does not
    surface this as drift because the pinned version still matches what is deployed.

    This compares the major version pinned by the assignment against the major version of the latest
    built-in definition and returns an advisory when the built-in has moved ahead.

    Only built-in definitions are considered; custom definitions are versioned by the EPAC repo itself.
    Only major versions are compared - minor and patch updates are picked up automatically by the
    wildcard in the assignment.

    .PARAMETER PolicyDefinitionId
    Resource id of the Policy or Policy Set definition referenced by the assignment.

    .PARAMETER DefinitionVersion
    The version or version wildcard pinned by the assignment. An empty value means the assignment
    follows the latest version and therefore never needs an advisory.

    .PARAMETER PolicyDefinition
    The latest definition object as loaded by EPAC, used to read policyType and the published version.

    .OUTPUTS
    Hashtable with policyDefinitionId, displayName, assignedVersion, assignedMajor, latestVersion and
    latestMajor when a newer major version exists, otherwise $null.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $PolicyDefinitionId,

        [Parameter(Mandatory = $false)]
        [string] $DefinitionVersion,

        [Parameter(Mandatory = $false)]
        $PolicyDefinition
    )

    if ([string]::IsNullOrWhiteSpace($DefinitionVersion)) {
        # Assignment tracks the latest version, nothing to advise on
        return $null
    }
    if ($null -eq $PolicyDefinition) {
        return $null
    }

    $properties = Get-PolicyResourceProperties -PolicyResource $PolicyDefinition
    if ($properties.policyType -ne "BuiltIn") {
        return $null
    }

    $latestVersion = $properties.version
    if ([string]::IsNullOrWhiteSpace($latestVersion) -and $properties.metadata) {
        $latestVersion = $properties.metadata.version
    }

    $assignedMajor = Get-MajorVersionNumber -Version $DefinitionVersion
    $latestMajor = Get-MajorVersionNumber -Version $latestVersion
    if ($null -eq $assignedMajor -or $null -eq $latestMajor) {
        return $null
    }
    if ($latestMajor -le $assignedMajor) {
        return $null
    }

    $displayName = $properties.displayName
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        $displayName = $PolicyDefinition.name
    }

    return @{
        policyDefinitionId = $PolicyDefinitionId
        displayName        = $displayName
        assignedVersion    = $DefinitionVersion
        assignedMajor      = $assignedMajor
        latestVersion      = $latestVersion
        latestMajor        = $latestMajor
    }
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
