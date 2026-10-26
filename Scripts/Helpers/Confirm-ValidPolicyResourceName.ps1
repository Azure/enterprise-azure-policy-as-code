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

function Get-PolicyResourceLengthError {
    # Azure limits Policy resource names to 64 characters (24 for Assignments at Management Group scope),
    # displayNames to 128 characters and descriptions to 512 characters. Exceeding a limit fails the deployment.
    [CmdletBinding()]
    param (
        [string] $Name = "",
        [string] $DisplayName = "",
        [string] $Description = "",
        [int] $MaxNameLength = 64
    )

    $lengthErrors = [System.Collections.ArrayList]::new()
    if ($Name.Length -gt $MaxNameLength) {
        $null = $lengthErrors.Add("name '$Name' is $($Name.Length) characters long (max $MaxNameLength)")
    }
    if ($DisplayName.Length -gt 128) {
        $null = $lengthErrors.Add("displayName '$($DisplayName.Substring(0, 32))...' is $($DisplayName.Length) characters long (max 128)")
    }
    if ($Description.Length -gt 512) {
        $null = $lengthErrors.Add("description '$($Description.Substring(0, 32))...' is $($Description.Length) characters long (max 512)")
    }
    return , $lengthErrors.ToArray()
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
