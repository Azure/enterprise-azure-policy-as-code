function Test-IsSensitivePath {
    <#
    .SYNOPSIS
    Determines if a JSON Pointer path contains sensitive data that should be masked.
    
    .DESCRIPTION
    Checks if a path or parameter type indicates sensitive information like passwords, secrets, keys, or tokens.
    Used to prevent accidental exposure of credentials in diff output.
    
    .PARAMETER Path
    The JSON Pointer path to check
    
    .PARAMETER ParameterType
    Optional parameter type from policy definition (e.g., "secureString")
    
    .EXAMPLE
    Test-IsSensitivePath -Path "/parameters/adminPassword/value"
    # Returns: $true
    
    .EXAMPLE
    Test-IsSensitivePath -Path "/parameters/maxRetries/value" -ParameterType "int"
    # Returns: $false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,
        
        [Parameter(Mandatory = $false)]
        [string] $ParameterType = ""
    )
    
    # Check parameter type
    if ($ParameterType -eq "secureString" -or $ParameterType -eq "secureObject") {
        return $true
    }
    
    # Check path for sensitive keywords (case-insensitive)
    $sensitivePatterns = @(
        'secret',
        'password',
        'pwd',
        'key',
        'token',
        'credential',
        'connectionstring',
        'accountkey',
        'accesskey',
        'apikey',
        'sas',
        'privatekey'
    )
    
    foreach ($pattern in $sensitivePatterns) {
        if ($Path -match $pattern) {
            return $true
        }
    }
    
    return $false
}
