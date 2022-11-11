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

    .PARAMETER Arguments
    The remaining arguments are passed to the az cli.

    <# Enable -Verbose, -Force and -WhatIf. #>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [switch] $AsHashTable,
        [switch] $SuppressOutput,

        [string] $policyDefinitionsScopeId = $null,
        [string] $assignmentScopeId = $null,
        [string] $assignmentId = $null,

        [Parameter(ValueFromRemainingArguments)]
        [string[]] $Arguments

    )

    $hostInfo = Get-Host
    $ForegroundColor = $hostInfo.ui.rawui.ForegroundColor
    $BackgroundColor = $hostInfo.ui.rawui.BackgroundColor

    $result = $null
    try {
        if ("" -ne $policyDefinitionsScopeId) {
            if ($policyDefinitionsScopeId.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                $name = $policyDefinitionsScopeId -replace "/providers/Microsoft.Management/managementGroups/"
                $result = az @Arguments --management-group $name --only-show-errors --output json
            }
            elseif ($policyDefinitionsScopeId.StartsWith("/subscriptions/")) {
                $id = $policyDefinitionsScopeId -replace "/subscriptions/"
                $result = az @Arguments --subscription $id --only-show-errors --output json
            }
        }
        elseif ("" -ne $assignmentScopeId) {
            if ($assignmentScopeId.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                $name = $policyDefinitionsScopeId -replace "/providers/Microsoft.Management/managementGroups/"
                $result = az @Arguments --management-group $name --only-show-errors --output json
            }
            elseif ($assignmentScopeId.StartsWith("/subscriptions/")) {
                $splits = $scope.Split('/')
                $subscriptionId = $splits[2]
                if ($splits.Length -ge 5) {
                    $rg = $splits[-1]
                    $result = az @Arguments --subscription $subscriptionId --resource-group $rg --only-show-errors --output json
                }
                else {
                    $result = az @Arguments --subscription $subscriptionId --only-show-errors --output json
                }
            }
        }
        elseif ("" -ne $assignmentId) {
            $name = $assignmentId.Split('/')[-1]
            $scope = $assignmentId -ireplace [regex]::Escape("/providers/Microsoft.Authorization/policyAssignments/$name"), ""
            $result = az @Arguments --scope $scope --name $name --only-show-errors --output json
        }
        else {
            $result = az @Arguments --only-show-errors --output json
        }
        if (!$?) {
            throw "Command 'az $Arguments' command exited with error"
        }
    }
    finally {
        # Restore console colors, as Azure CLI likely to change them.
        $hostInfo.ui.rawui.ForegroundColor = $ForegroundColor
        $hostInfo.ui.rawui.BackgroundColor = $BackgroundColor
    }

    if ($null -ne $result) {
        try {
            $obj = $null
            $obj = $result | ConvertFrom-Json -AsHashTable:$AsHashTable
            if (!$SuppressOutput) {
                return $obj
            }
        }
        catch {
            Write-Error "Command 'az $Arguments' returned an error message: $($result)" -ErrorAction Stop
        }
    }
}