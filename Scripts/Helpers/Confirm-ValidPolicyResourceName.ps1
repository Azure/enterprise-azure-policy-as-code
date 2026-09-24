function Confirm-ValidPolicyResourceName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $Name
    )

    $invalidCharacters = @('%', '&', '\', '?', '/', '<', '>', ':', '#', '*', '+')
    foreach ($character in $Name.ToCharArray()) {
        if ($character -in $invalidCharacters -or [char]::IsControl($character)) {
            return $false
        }
    }

    return -not $Name.EndsWith(" ")
}

function Assert-ValidPolicyResourceName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $ResourceType
    )

    if (-not (Confirm-ValidPolicyResourceName -Name $Name)) {
        Write-Error "$ResourceType name '$Name' contains invalid characters '%, &, \, ?, /, <, >, :, #, *, +' or control characters, or ends with a space." -ErrorAction Stop
    }
}
