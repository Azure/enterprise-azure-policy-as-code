#Requires -PSEdition Core
function Get-DeepClone {
    [cmdletbinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        [PSObject] $InputObject,

        [switch] $AsHashTable
    )

    $json = ConvertTo-Json $InputObject -Depth 100 -Compress
    $clone = ConvertFrom-Json $json -Depth 100 -AsHashtable:$AsHashTable
    return $clone

    # if ($InputObject -is [hashtable]) {
    #     $clone = @{}
    #     foreach ($key in $InputObject.Keys) {
    #         $value = $InputObject[$key]
    #         if ($value -is [hashtable] -or $value -is [array]) {
    #             $clone[$key] = Get-DeepClone -InputObject $value
    #         }
    #         else {
    #             $clone[$key] = $value
    #         }
    #     }
    #     return $clone
    # }
    # elseif ($InputObject -is [array]) {
    #     $clone = @()
    #     foreach ($item in $InputObject) {
    #         if ($item -is [hashtable] -or $item -is [array]) {
    #             $clone += Get-DeepClone  -InputObject $item
    #         }
    #         else {
    #             $cone += $item
    #         }
    #     }
    #     return $clone
    # }
    # else {
    #     return $InputObject
    # }
}
