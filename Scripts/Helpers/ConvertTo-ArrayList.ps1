function ConvertTo-ArrayList {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        $InputObject = $null,

        [switch] $skipNull
    )

    $list = [System.Collections.ArrayList]::new()
    if ($null -ne $InputObject -or !$skipNull) {
        $null = $list.Add($InputObject)
    }
    Write-Output $list -NoEnumerate
}
