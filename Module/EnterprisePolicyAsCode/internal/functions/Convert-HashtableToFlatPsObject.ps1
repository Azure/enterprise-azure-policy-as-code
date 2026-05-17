function Convert-HashtableToFlatPsObject {
    param (
        [Parameter(Mandatory = $true)]
        $Hashtable
    )
    $newObject = @()
    Remove-Variable valueObject -ErrorAction SilentlyContinue
    foreach ($hash in $Hashtable) {
        $valueObject = New-Object PSObject
        foreach ($hKey in $Hash.Keys) {
            if (!($Hash.$hKey -is [string] -or $Hash.$hKey -is [int] -or $Hash.$hKey -is [double] -or $Hash.$hKey -is [decimal] -or $Hash.$hKey -is [datetime] -or $Hash.$hKey -is [char] -or $Hash.$hKey -is [bool])) {
                if (!($valueObject)) {
                    $valueObject = New-Object PSObject -Property @{$hkey = $(ConvertTo-Json -InputObject $Hash.$hKey -depth 100 -Compress) }
                }
                else {
                    Add-Member -InputObject $valueObject -MemberType NoteProperty -Name $hKey -Value $(ConvertTo-Json -InputObject $Hash.$hKey -depth 100 -Compress)
                }
                
            }
            else {
                if (!($valueObject)) {
                    $valueObject = New-Object PSObject -Property @{$hkey = $hash.$hkey }
                }
                else {
                    Add-Member -InputObject $valueObject -MemberType NoteProperty -Name $hKey -Value $Hash.$hKey
                }
            }
            $newObject += $valueObject
            Remove-Variable hKey -ErrorAction SilentlyContinue
        }
        Remove-Variable hash -ErrorAction SilentlyContinue
        Remove-Variable valueObject -ErrorAction SilentlyContinue
    }
    return $newObject
}
