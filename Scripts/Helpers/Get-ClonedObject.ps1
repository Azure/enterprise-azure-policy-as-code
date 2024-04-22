function Get-ClonedObject {
    [CmdletBinding()]
    param(
        [parameter(Position = 0, ValueFromPipeline = $true)]
        $InputObject,

        [switch] $AsHashTable,
        [switch] $AsShallowClone
    )

    $clone = $InputObject
    if ($AsHashTable) {
        # only support deep cloning to hashtable
        if ($null -ne $InputObject) {
            $json = ConvertTo-Json $InputObject -Depth 100 -Compress
            $clone = ConvertFrom-Json $json -NoEnumerate -Depth 100 -AsHashTable
        }
        else {
            $clone = @{}
        }
    }
    else {
        if ($null -ne $InputObject) {
            if ($AsShallowClone) {
                if ($InputObject -is [System.ICloneable]) {
                    $clone = $InputObject.Clone()
                }
            }
            elseif ($InputObject -is [System.ValueType] -or $InputObject -is [datetime]) {
                $clone = $InputObject
            }
            else {
                if ($InputObject -is [System.Collections.IDictionary]) {
                    $clone = $InputObject.Clone()
                    foreach ($key in $InputObject.Keys) {
                        $value = $InputObject[$key]
                        $isComplex = -not ($null -eq $value -or $value -is [string] -or $value -is [System.ValueType] -or $value -is [datetime])
                        if ($isComplex) {
                            $clone[$key] = Get-ClonedObject -InputObject $value
                        }
                    }
                }
                elseif ($InputObject -is [System.Collections.IList]) {
                    $clone = $InputObject.Clone()
                    for ($i = 0; $i -lt $clone.Count; $i++) {
                        $value = $InputObject[$i]
                        $isComplex = -not ($null -eq $value -or $value -is [string] -or $value -is [System.ValueType] -or $value -is [datetime])
                        if ($isComplex) {
                            $clone[$i] = Get-ClonedObject -InputObject $value
                        }
                        else {
                            # assumin uniform IList
                            break
                        }
                    }
                }
                elseif ($InputObject -is [psobject]) {
                    $clone = $InputObject.PSObject.Copy()
                    foreach ($propertyName in $InputObject.PSObject.Properties.Name) {
                        $value = $InputObject.$propertyName
                        $isComplex = -not ($null -eq $value -or $value -is [string] -or $value -is [System.ValueType] -or $value -is [datetime])
                        if ($isComplex) {
                            $clone.$propertyName = Get-ClonedObject -InputObject $value
                        }
                    }
                }
            }
        }
    }
    if ($clone -is [System.Collections.IList]) {
        Write-Output $clone -NoEnumerate
    }
    else {
        Write-Output $clone
    }
}
