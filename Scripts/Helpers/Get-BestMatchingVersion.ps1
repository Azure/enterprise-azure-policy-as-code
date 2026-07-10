function Get-BestMatchingVersion {
    <#
    .SYNOPSIS
        Returns the highest available version that matches a (possibly wildcard) pinned version.

    .DESCRIPTION
        Given a pinned version string (which may contain wildcards such as '1.3.*' or
        '1.3.*-preview') and a list of concrete available version strings, this returns the
        highest available version that satisfies the pinned version. Returns $null when no
        available version matches.

        Matching and ordering are delegated to Compare-SemanticVersion which understands
        wildcards ('*') and the '-preview' suffix.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $PinnedVersion,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $AvailableVersions
    )

    $matchingVersions = [System.Collections.ArrayList]::new()
    foreach ($availableVersion in $AvailableVersions) {
        if ([string]::IsNullOrWhiteSpace($availableVersion)) {
            continue
        }
        if ((Compare-SemanticVersion -Version1 $availableVersion -Version2 $PinnedVersion) -eq 0) {
            $null = $matchingVersions.Add($availableVersion)
        }
    }

    if ($matchingVersions.Count -eq 0) {
        return $null
    }

    $bestVersion = $matchingVersions[0]
    foreach ($candidateVersion in $matchingVersions) {
        if ((Compare-SemanticVersion -Version1 $candidateVersion -Version2 $bestVersion) -gt 0) {
            $bestVersion = $candidateVersion
        }
    }

    return $bestVersion
}
