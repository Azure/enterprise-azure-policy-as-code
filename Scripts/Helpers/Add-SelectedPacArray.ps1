function Add-SelectedPacArray {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $PacSelector,

        [System.Collections.ArrayList] $OutputArrayList
    )

    $array = $InputObject.$PacSelector
    if ($null -ne $array) {
        if ($array -isnot [array]) {
            $array = @($array)
        }
        $null = $OutputArrayList.AddRange($array)
    }

    $array = $InputObject["*"]
    if ($null -ne $array) {
        if ($array -isnot [array]) {
            $array = @($array)
        }
        $null = $OutputArrayList.AddRange($array)
    }
}
