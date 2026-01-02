function New-DiffEntry {
    <#
    .SYNOPSIS
    Creates a standardized diff entry object for tracking changes between resources.
    
    .DESCRIPTION
    Creates a diff entry with operation type, JSON Pointer path, before/after values, and classification.
    Follows RFC 6902 JSON Patch format for path notation.
    
    .PARAMETER Operation
    The type of change: add, remove, or replace
    
    .PARAMETER Path
    JSON Pointer path to the changed property (e.g., /parameters/maxAge/value)
    
    .PARAMETER Before
    The previous value (null for add operations)
    
    .PARAMETER After
    The new value (null for remove operations)
    
    .PARAMETER Classification
    The type of property being changed: parameter, metadata, policyRule, override, identity, resourceSelector, core
    
    .EXAMPLE
    New-DiffEntry -Operation "replace" -Path "/parameters/maxAge/value" -Before 90 -After 120 -Classification "parameter"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("add", "remove", "replace")]
        [string] $Operation,
        
        [Parameter(Mandatory = $true)]
        [string] $Path,
        
        [Parameter(Mandatory = $false)]
        $Before,
        
        [Parameter(Mandatory = $false)]
        $After,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("parameter", "metadata", "policyRule", "override", "identity", "resourceSelector", "core", "array")]
        [string] $Classification = "core"
    )
    
    return [PSCustomObject]@{
        op             = $Operation
        path           = $Path
        before         = $Before
        after          = $After
        classification = $Classification
    }
}
