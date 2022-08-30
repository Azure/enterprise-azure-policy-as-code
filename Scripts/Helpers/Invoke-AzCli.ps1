function Get-EscapedString($Argument) {
    $escaped = "$Argument" -replace '(["\\])', '\$0'
    "`"${escaped}`""
}

function Invoke-AzCli {
    <#
    .SYNOPSIS
    Invokes the az cli from PowerShell providing better error handling and converts the output from JSON to a custom object or a hash table.

    .DESCRIPTION
    Invokes the az cli from PowerShell:
        * SplatSelection
            * Specified: Filters out extraneous keys in hashtable not specified in SplatSelection
            * Ommited: Splat is applied
        * Infers the format to use for each dat value in hashtable
        *   SplatSelection may override the inferred format
        * String values are escaped
        * Formating based on inferred or explicit format specifier (SplatSelection)
            json: writes json string to a temporary file and uses the filename as the argument
                --argName filename
            array: optional, value must be an array of simple types or a single item - creates
                --argName followed by a space separted list of values
            key: optional, automatic if value is $null - creates
                    --argName
            keyvalues: value must be a hashtable or can be converted to a hashtable - creates
                --argName akey=avalue bkey=bvalue ...
            value: optional, required if splat parameter is used to change the argName for a single value (see next format below)
    Unless specified otherwise, converts the output from JSON to a custom object.

    .PARAMETER Arguments
    The remaining arguments are passed to the az cli.

    .PARAMETER Splat
    Input a hashtable similar to what a splat does for Cmdlets. Do not use the @operator, use standard $ instead.
    Do not add the - or -- to the key in the hashtable (script will add it).

    .PARAMETER SplatSelection
    String with (must be quoted) containing a space separated list of splat parameters to use and
    optionally transforms acceptable to az cli.
    Forms:
        "argName" infers the type from the data type
        "argName/format" overrides inferred format
        "argName/newArgName" changes the argName to newArgName (only valid if newArgName is not one of the formats)
        "argName/format/newArgName" overrides inferred format and changes the argName to newArgName
    #>

    <# Enable -Verbose, -Force and -WhatIf. #>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Switch] $SuppressOutput,

        [Parameter()]
        $Splat,

        [Parameter()]
        [string] $SplatTransform = $null,

        [Parameter()]
        [switch]
        $AsHashTable,

        [Parameter(ValueFromRemainingArguments)]
        [string[]] $Arguments
    )

    $additionalArguments = @()
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    if ($verbose) {
        $additionalArguments += '--verbose'
    }
    $hostInfo = Get-Host
    $ForegroundColor = $hostInfo.ui.rawui.ForegroundColor
    $BackgroundColor = $hostInfo.ui.rawui.BackgroundColor
    $result = $null
    $tempFiles = @()

    $splatArguments = $()
    if ($Splat) {
        if (-not ($Splat -is [hashtable])) {
            $ht = $Splat | ConvertTo-HashTable
            $Splat = $ht
        }
        if ($Splat.Count -gt 0) {
            # ignore an empty splat
            $transforms = $Splat.Keys
            if ($SplatTransform) {
                $transforms = $SplatTransform.Split()
            }
            foreach ($transform in $transforms) {
                $splits = $transform.Split("/")
                $splatSelector = $splits[0]
                if ($Splat.ContainsKey($splatSelector)) {
                    $argName = $splatSelector.ToLower()
                    $splatValue = $Splat[$splatSelector]

                    # Infer format from data type
                    $type = "value"
                    if ($null -eq $splatValue -or $splatValue -eq "") {
                        $type = "key"
                    }
                    elseif ($splatValue -is [array]) {
                        $type = "array"
                        foreach ($value in $splatValue) {
                            if (-not($splatValue -is [string] -or $splatValue -is [System.ValueType])) {
                                $type = "json"
                                break
                            }
                        }
                    }
                    elseif ($splatValue -is [hashtable]) {
                        $type = "keyvalues"
                    }
                    elseif ($splatValue -is [string] -or $splatValue -is [System.ValueType]) {
                        $type = "value"
                    }
                    else {
                        $type = "json"
                    }

                    # Check overrides
                    if ($splits.Length -in @(2, 3)) {
                        if ($splits[1] -in @("json", "array", "keyvalues", "key", "value")) {
                            # Infered type is explicitly overriden
                            $type = $splits[1]
                            if ($splits.Length -eq 3) {
                                $argName = $splits[2].ToLower()
                            }
                        }
                        elseif ($splits.Length -eq 2) {
                            # Inferred type used and the second part is the newArgName
                            $argName = $splits[1].ToLower()
                        }
                        else {
                            # Unknown type specified
                            Write-Error "Invalid `SplatTransform = '$transform', second part must be one of the following json, array, keyvalues, key, string, value." -ErrorAction Stop
                        }
                    }
                    switch ($type) {
                        "json" {
                            $tempFile = New-TemporaryFile
                            $tempFiles += $tempFile
                            $null = ConvertTo-Json $splatValue -Depth 100 | Out-File $tempFile.FullName -Force
                            $splatArguments += @("--$argName", $tempFile.FullName)
                            break
                        }
                        "array" {
                            $splatArguments += @("--$argName")
                            foreach ($value in $splatValue) {
                                if ($value -is [string]) {
                                    $value = Get-EscapedString($value)
                                }
                                $splatArguments += @($value)
                            }
                            break
                        }
                        "keyvalue" {
                            if (-not ($splatValue -is [hashtable])) {
                                $splatValue = $splatValue | ConvertTo-HashTable
                            }
                            $splatArguments += @("--$argName")
                            foreach ($key in $splatValue.Keys) {
                                $value = $splatValue.$key
                                if ($value -is [string]) {
                                    $value = Get-EscapedString($value)
                                }
                                $splatArguments += @("$($key)=$($value)")
                            }
                            break
                        }
                        "key" {
                            # Just the key (no value)
                            $splatArguments += @("--$argName")
                            break
                        }
                        "value" {
                            # ValueType
                            if ($splatValue -is [string]) {
                                $splatValue = Get-EscapedString($splatValue)
                            }
                            $splatArguments += @("--$argName", $splatValue)
                            break
                        }
                        Default {
                            Write-Error "Unknown format ""$_"" for -SplatTransform specified ""$transform""" -ErrorAction Stop
                            break
                        }
                    }
                }
            }
        }
    }

    $result = ""
    try {
        $result = az @Arguments @splatArguments @additionalArguments --only-show-errors --output json
        if (!$?) {
            throw "Command 'az $Arguments $splatArguments' command exited with error"
        }
    }
    finally {
        # Cleanup any temp files creaated for JSON
        foreach ($tempFile in $tempFiles) {
            Remove-Item $tempFile.FullName -Force
        }

        # Restore console colors, as Azure CLI likely to change them.
        $hostInfo.ui.rawui.ForegroundColor = $ForegroundColor
        $hostInfo.ui.rawui.BackgroundColor = $BackgroundColor
    }

    if ($null -ne $result) {
        try {
            $obj = $null
            if ($AsHashTable.IsPresent) {
                $obj = $result | ConvertFrom-Json -AsHashTable
            }
            else {
                $obj = $result | ConvertFrom-Json
            }
            if (!$SuppressOutput.IsPresent) {
                return $obj
            }
        }
        catch {
            Write-Error "Command 'az $Arguments $splatArguments' retrurned an error message: $($result)" -ErrorAction Stop
        }
    }
}