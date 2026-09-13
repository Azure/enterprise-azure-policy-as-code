function ConvertTo-AzPolicyRestPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Id
    )

    $policyResourceId = [regex]::Match(
        $Id,
        '^(?<parent>.*/providers/Microsoft\.Authorization/(?:policyAssignments|policyExemptions)/)(?<name>[^/]+)$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if (-not $policyResourceId.Success) {
        return $Id
    }

    $name = [System.Uri]::UnescapeDataString($policyResourceId.Groups['name'].Value)
    $encodedName = [System.Uri]::EscapeDataString($name)
    return "$($policyResourceId.Groups['parent'].Value)$encodedName"
}
