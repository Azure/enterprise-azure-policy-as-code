#Requires -PSEdition Core
function Get-DeepClone {
    [cmdletbinding()]
    param(
        $InputObject
    )

    if ($InputObject -is [hashtable]) {
        $clone = @{}
        foreach ($key in $InputObject.Keys) {
            $clone[$key] = Get-DeepClone -InputObject $InputObject[$key]
        }
        return $clone
    }
    elseif ($InputObject -is [array]) {
        $clone = @()
        foreach ($item in $InputObject) {
            $clone += Get-DeepClone  -InputObject $item
        }
        return , $clone
    }
    else {
        return $InputObject
    }
}
