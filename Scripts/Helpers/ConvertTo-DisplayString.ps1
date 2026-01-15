function ConvertTo-DisplayString {
    <#
    .SYNOPSIS
        Converts a value to a formatted string for display purposes.
    
    .DESCRIPTION
        Formats values for consistent display output:
        - null values become "null"
        - strings are wrapped in quotes
        - other objects are converted to compressed JSON
    
    .PARAMETER Value
        The value to format for display.
    
    .EXAMPLE
        ConvertTo-DisplayString -Value $myValue
    
    .EXAMPLE
        $displayStr = ConvertTo-DisplayString $null
        # Returns: "null"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $Value
    )
    
    if ($null -eq $Value) {
        return "null"
    }
    
    if ($Value -is [string]) {
        return "`"$Value`""
    }
    
    $Value | ConvertTo-Json -Compress -Depth 100
}
