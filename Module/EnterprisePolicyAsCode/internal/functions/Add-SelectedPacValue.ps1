function Add-SelectedPacValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $PacSelector,

        [Parameter(Mandatory = $true)]
        [hashtable] $OutputObject,

        [Parameter(Mandatory = $true)]
        [string] $OutputKey
    )

    $value = $InputObject.$PacSelector
    if ($null -eq $value) {
        $value = $InputObject["*"]
    }

    if ($null -ne $value) {
        if ($value -is [array]) {
            Write-Error "Value for '$PacSelector' is an array. It must be a single value. value is $(ConvertTo-Json $InputObject -Depth 100 -Compress)" -ErrorAction Stop
        }
        $OutputObject[$OutputKey] = $value
    }
}
