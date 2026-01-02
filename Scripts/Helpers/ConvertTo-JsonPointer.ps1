function ConvertTo-JsonPointer {
    <#
    .SYNOPSIS
    Converts a property path to RFC 6902 JSON Pointer format.
    
    .DESCRIPTION
    Generates a JSON Pointer path from a series of property names or array indices.
    Handles special characters and escaping according to RFC 6902.
    
    .PARAMETER PathSegments
    Array of path segments (property names or array indices)
    
    .EXAMPLE
    ConvertTo-JsonPointer -PathSegments @("parameters", "maxAge", "value")
    # Returns: /parameters/maxAge/value
    
    .EXAMPLE
    ConvertTo-JsonPointer -PathSegments @("policyDefinitions", "[policyDefId]")
    # Returns: /policyDefinitions[policyDefId]
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $PathSegments
    )
    
    if ($PathSegments.Count -eq 0) {
        return ""
    }
    
    $pointer = ""
    foreach ($segment in $PathSegments) {
        # Handle array identity notation (already formatted as [id])
        if ($segment -match '^\[.*\]$') {
            $pointer += $segment
        }
        else {
            # Escape special characters per RFC 6902
            # ~ must be escaped as ~0
            # / must be escaped as ~1
            $escapedSegment = $segment -replace '~', '~0' -replace '/', '~1'
            $pointer += "/$escapedSegment"
        }
    }
    
    return $pointer
}
