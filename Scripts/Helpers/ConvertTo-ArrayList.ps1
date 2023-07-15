function ConvertTo-ArrayList {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        $InputObject = $null,

        [switch] $SkipNull
    )

    $list = [System.Collections.ArrayList]::new()
    if ($null -ne $InputObject -or !$SkipNull) {
        $null = $list.Add($InputObject)
    }
    Write-Output $list -NoEnumerate
}
