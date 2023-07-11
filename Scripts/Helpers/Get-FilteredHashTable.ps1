function Get-FilteredHashTable {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = "Hashtable or custom object containing the values needed.")]
        [PSCustomObject] $Splat,

        [Parameter(HelpMessage = "
        Format is a string with a space separated list of substrings. Each substring:
        - argName - selects that argument (if it exists) from the splat to the returned splat
        - argName/commandArgName - changes the argName in the returned splat to the commandArgName
        - argName:typeOverride - selects that argument (if it exists) from the splat to the returned splat AND overrides the implied argument value type
        - argName/commandArgName:typeOverride - changes the argName in the returned splat to the commandArgName AND overrides the implied argument value type
        Examples:
        - Id DisplayName Description Metadata ExemptionCategory ExpiresOn ClearExpiration PolicyDefinitionReferenceIds/PolicyDefinitionReferenceId
        - name/Name displayName/DisplayName description/Description parameter/Parameter:json Policy:json
        ")]
        [string] $SplatTransform = $null,

        [Parameter(HelpMessage = "Output will be formatted for use in az cli (instead of PowerShell modules")]
        [switch] $FormatForAzCli

    )

    [hashtable] $filteredSplat = @{}
    if ($null -ne $Splat) {
        # ignore an empty splat
        if (-not ($Splat -is [hashtable])) {
            $ht = ConvertTo-HashTable $Splat
            $Splat = $ht
        }

        $transforms = $Splat.Keys
        if ($SplatTransform) {
            $transforms = $SplatTransform.Split()
        }
        foreach ($transform in $transforms) {
            $typeOverrideSplits = $transform.Split(":")
            $argNamesTransform = $typeOverrideSplits[0]
            $argNameSplits = $argNamesTransform.Split("/")
            if (!($argNameSplits.Count -in @( 1, 2 ) -and $typeOverrideSplits.Count -in @( 1, 2 ))) {
                Write-Error "Get-FilteredHashTable: splatTransform `"$SplatTransform`" contains an invalid element `"$transform`" - code bug" -ErrorAction Stop
            }
            $argName = $argNameSplits[0]
            $commandArgName = $argNameSplits[-1]
            $type = "infer"
            if ($typeOverrideSplits.Count -eq 2) {
                $type = $typeOverrideSplits[1]
            }
            if ($type -notin @("infer", "json", "hashtable", "array", "key", "value", "keyValue", "policyScope")) {
                Write-Error "Get-FilteredHashTable: splatTransform `"$SplatTransform`" contains an invalid type override in element `"$transform`" - code bug" -ErrorAction Stop
            }

            if ($Splat.ContainsKey($argName)) {

                $SplatValue = $Splat.$argName
                if ($null -ne $SplatValue) {

                    if ($type -eq "infer") {
                        # Infer format from data type
                        if ($SplatValue -is [array]) {
                            $type = "array"
                            foreach ($value in $SplatValue) {
                                if (-not($value -is [string] -or $value -is [System.ValueType])) {
                                    $type = "json"
                                    break
                                }
                            }
                        }
                        elseif ($SplatValue -is [string] -or $SplatValue -is [System.ValueType]) {
                            $type = "value"
                        }
                        else {
                            $type = "json"
                        }
                    }

                    switch ($type) {
                        json {
                            $argValue = ConvertTo-Json $SplatValue -Depth 100 -Compress
                            $null = $filteredSplat.Add($commandArgName, $argValue)
                        }
                        hashtable {
                            $argValue = Get-DeepClone $SplatValue -AsHashtable
                            $null = $filteredSplat.Add($commandArgName, $argValue)
                        }
                        key {
                            # Just the key (no value)
                            $null = $filteredSplat.Add($commandArgName, $true)
                        }
                        value {
                            $null = $filteredSplat.Add($commandArgName, $SplatValue)
                        }
                        array {
                            $null = $filteredSplat.Add($commandArgName, $SplatValue)
                        }
                        policyScope {
                            $argName, $argValue = Split-ScopeId -ScopeId $SplatValue
                            $filteredSplat.Add($argName, $argValue)
                        }
                    }
                }
            }
        }
    }

    return $filteredSplat
}
