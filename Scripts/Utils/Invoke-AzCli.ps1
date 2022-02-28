function Get-EscapedString($Argument) {
    $escaped = "$Argument" -replace '(["\\])', '\$0'
    "`"${escaped}`""
}

function Invoke-AzCli {
    <#
    .SYNOPSIS
    Invokes the az cli from PowerShell providing better error handling and converts the output from JSON to a custom object or a hash table.
 
    .DESCRIPTION
    Invokes the az cli from PowerShell.
 
    Unless specified otherwise, converts the output from JSON to a custom object. This make further dealing with the output in PowerShell much easier.
 
    .PARAMETER Arguments
    All the remaining arguments are passedon the az cli.

    .PARAMETER Splat
    Input a hashtable similar to what a splat does for Cmdlets. Do not use the @operator, use standard $ instead. Do not add the - or -- to the key in the hashtable

    .PARAMETER SplatSelection
    String with (must be quoted) a space separated list of splat parameters to use (in case your hashtable has additional entries)
 
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

    begin {
        $additionalArguments = @()
        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        if ($verbose) {
            $additionalArguments += '--verbose'
        }
        $hostInfo = Get-Host
        $ForegroundColor = $hostInfo.ui.rawui.ForegroundColor
        $BackgroundColor = $hostInfo.ui.rawui.BackgroundColor
    }

    process {
        $result = $null

        $splatArguments = $()
        if ($Splat) {
            if (-not ($Splat -is [hashtable])) {
                $ht = $Splat | ConvertTo-HashTable
                $Splat = $ht
            }
            if ($Splat.Count -gt 0) {
                # ignore an empty splat
                if ($SplatTransform) {
                    $transforms = $SplatTransform.Split()
                    foreach ($transform in $transforms) {
                        $splits = $transform.Split("/")
                        $splatSelector = $splits[0]
                        if ($Splat.ContainsKey($splatSelector)) {
                            switch ($splits.Length) {
                                1 { 
                                    $splatArguments += @("--$($splatSelector.ToLower())", (Get-EscapedString $Splat[$splatSelector]))
                                    break
                                }
                                2 {
                                    $argName = $splits[1].ToLower()
                                    $splatArguments += @("--$argName", (Get-EscapedString $Splat[$splatSelector]))
                                    break
                                }
                                3 {
                                    $argName = $splits[1].ToLower()
                                    switch ($splits[2]) {
                                        "json" {
                                            $splatValue = $Splat[$splatSelector] | ConvertTo-Json -Depth 100 -Compress
                                            $splatArguments += @("--$argName", (Get-EscapedString $splatValue))
                                            break
                                        }
                                        "array" {
                                            $list = $Splat[$splatSelector]
                                            if ($list -is [array] -and $list.Length -gt 0) {
                                                $splatArguments += @("--$argName")
                                                foreach ($item in $list) {
                                                    $splatArguments += @(Get-EscapedString $item)
                                                }
                                            }
                                            break
                                        }
                                        "keyvalue" {
                                            $value = $Splat[$splatSelector]
                                            if (-not ($value -is [hashtable])) {
                                                $value = $value | ConvertTo-HashTable
                                            }
                                            if ($value -is [hashtable] -and $value.Count -gt 0) {
                                                $splatArguments += @("--$argName")
                                                foreach ($key in $value.Keys) {
                                                    $splatArguments += @(Get-EscapedString "$($key)=$($value[$key])")
                                                }
                                            }
                                            break
                                        }
                                        "key" {
                                            # Just the key (no value)
                                            $splatArguments += @("--$argName")
                                            break
                                        }
                                        "string" {
                                            # default value, can be ommited
                                            $splatArguments += @("--$argName", (Get-EscapedString $Splat[$splatSelector]))
                                            break
                                        }
                                        Default { throw "Unknown format ""$_"" for -SplatTransform specified ""$transform""" }
                                    }
                                    break
                                }
                                Default { throw "SplatTransform has too menay parts ""$transform""" }
                            }
                        }
                    }
                }
                else {
                    #use the entire Splat
                    foreach ($argumentName in $Splat.Keys) {
                        $splatArguments += @("--$($argumentName.ToLower())", (Get-EscapedString $Splat[$argumentName]))
                    }
                }
            }
        }

        $hadError = $false
        $result = $null
        try {
            $result = az @Arguments @splatArguments @additionalArguments
            $hadError = !$?
        }
        finally {
            # Restore console colors, as Azure CLI likely to change them.
            $hostInfo.ui.rawui.ForegroundColor = $ForegroundColor
            $hostInfo.ui.rawui.BackgroundColor = $BackgroundColor
        }

        if ($hadError) {
            throw "Command exited with error code $LASTEXITCODE"
        }
        elseif (!$SuppressOutput.IsPresent -and $null -ne $result) {
            if ($AsHashTable.IsPresent) {
                $result | ConvertFrom-Json -AsHashTable
            }
            else {
                $result | ConvertFrom-Json
            }
        }
    }
}
