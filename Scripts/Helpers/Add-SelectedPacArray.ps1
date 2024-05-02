function Add-SelectedPacArray {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $PacSelector,

        [Parameter(Mandatory = $false)]
        $ExistingList = $null
    )

    $OutputArrayList = [System.Collections.ArrayList]::new()
    if ($null -ne $ExistingList) {
        if ($ExistingList -isnot [System.Collections.IList]) {
            throw "ExistingList must be of type System.Collections.IList"
        }
        $null = $OutputArrayList.AddRange($ExistingList)
    }
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
    Write-Output $OutputArrayList -NoEnumerate
}
