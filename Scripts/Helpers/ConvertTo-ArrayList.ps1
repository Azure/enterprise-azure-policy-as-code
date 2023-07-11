function ConvertTo-ArrayList {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        $InputObject = $null,

        [switch] $SkipNull
    )

    $List = [System.Collections.ArrayList]::new()
    if ($null -ne $InputObject -or !$SkipNull) {
        $null = $List.Add($InputObject)
    }
    Write-Output $List -NoEnumerate
}
