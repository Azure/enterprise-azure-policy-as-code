function Get-AdoWikiRepositoryUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Organization,

        [Parameter(Mandatory = $true)]
        [string] $Project,

        [Parameter(Mandatory = $true)]
        [string] $Wiki,

        [string] $WikiClonePat
    )

    # Preserve configurations that already URL-encode names as a workaround.
    $encodedOrganization = [System.Uri]::EscapeDataString([System.Uri]::UnescapeDataString($Organization))
    $encodedProject = [System.Uri]::EscapeDataString([System.Uri]::UnescapeDataString($Project))
    $encodedWiki = [System.Uri]::EscapeDataString([System.Uri]::UnescapeDataString($Wiki))
    $authority = "dev.azure.com"
    if ($WikiClonePat) {
        $authority = "$($WikiClonePat):x-oauth-basic@$authority"
    }

    return "https://$authority/$encodedOrganization/$encodedProject/_git/$encodedWiki.wiki"
}
