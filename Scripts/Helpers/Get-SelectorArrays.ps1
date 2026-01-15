function Get-SelectorArrays {
    <#
    .SYNOPSIS
        Extracts 'in' and 'notIn' arrays from selector objects.
    
    .DESCRIPTION
        Parses policy override or resource selector objects to extract
        the 'in' and 'notIn' array values from nested selector structures.
        Used for comparing and displaying selector changes in policy assignments.
    
    .PARAMETER SelectorObject
        The object containing selectors property (e.g., override or resourceSelector).
    
    .OUTPUTS
        Hashtable with 'In' and 'NotIn' keys containing the extracted arrays.
    
    .EXAMPLE
        $arrays = Get-SelectorArrays -SelectorObject $override
        Write-Host "In values: $($arrays.In -join ', ')"
        Write-Host "NotIn values: $($arrays.NotIn -join ', ')"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $SelectorObject
    )
    
    $inValues = @()
    $notInValues = @()
    
    if ($SelectorObject.selectors) {
        foreach ($sel in $SelectorObject.selectors) {
            if ($sel.in) {
                $inValues += $sel.in
            }
            if ($sel.notIn) {
                $notInValues += $sel.notIn
            }
        }
    }
    
    @{
        In = $inValues
        NotIn = $notInValues
    }
}
