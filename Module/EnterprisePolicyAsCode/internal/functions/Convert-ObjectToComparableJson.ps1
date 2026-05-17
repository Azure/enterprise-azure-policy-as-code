function Convert-ObjectToComparableJson {
    <#
    .SYNOPSIS
        Converts an object to JSON string for comparison purposes.
    
    .DESCRIPTION
        Standardizes object-to-JSON conversion with consistent depth and compression settings.
        Returns the input if it's already a string.
    
    .PARAMETER Object
        The object to convert to JSON. If already a string, returns as-is.
    
    .PARAMETER Compress
        If specified, produces compressed JSON output (no whitespace).
    
    .EXAMPLE
        Convert-ObjectToComparableJson -Object $myHashtable
    
    .EXAMPLE
        Convert-ObjectToComparableJson -Object $myArray -Compress
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $Object,
        
        [Parameter(Mandatory = $false)]
        [switch] $Compress
    )
    
    if ($Object -is [string]) {
        return $Object
    }
    
    $Object | ConvertTo-Json -Depth 100 -Compress:$Compress
}
