#Requires -PSEdition Core

# @( "<initiative-id0>","<initiative-id0>" ) | .\Scripts\Operations\Get-AzInitiativeEffects.ps1 -InformationAction Continue || Out-File <file-path>

# Script calculates the effect paramters for the specified Initiative(s) outputing (based on selected param)
# * Comparison table (csv) to see the differences between 2 or more initaitives (most useful for compliance Initiatives)
# * List (csv) of default effects for a single initiative
# * Json snippet with parameters for an initiative
[CmdletBinding()]
param (
    [parameter(Position = 0)] [string] $initiativeSetSelector = "",
    [Parameter()] [string] $outputPath = "$PSScriptRoot/../../Output/AzEffects/Initiatives/",
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable PacDefinitionsRootFolder or './Definitions'.")] [string]$DefinitionsRootFolder
)


#region main

. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzInitiativeParameters.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyEffectsForInitiative.ps1"
. "$PSScriptRoot/../Helpers/Get-PolicyEffectDetails.ps1"
. "$PSScriptRoot/../Helpers/Get-ParmeterNameFromValueString.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"

# Get definitions
$InformationPreference = "Continue"
$environment = Initialize-Environment -DefinitionsRootFolder $DefinitionsRootFolder -retrieveFirstEnvironment -retrieveInitiativeSet -initiativeSetSelector  $initiativeSetSelector
$rootScope = $environment.rootScope

$collections = Get-AllAzPolicyInitiativeDefinitions -RootScope $rootScope -byId
$allPolicyDefinitions = $collections.builtInPolicyDefinitions + $collections.existingCustomPolicyDefinitions
$allInitiativeDefinitions = $collections.builtInInitiativeDefinitions + $collections.existingCustomInitiativeDefinitions

$initiativeSetSelector = $environment.initiativeSetSelector
$initiativeSet = $environment.initiativeSetToCompare
$initiativeIdList = $initiativeSet.initiatives

Write-Information "==================================================================================================="
Write-Information "Processing"
Write-Information "==================================================================================================="

# Collect raw data
[array] $list = @()
foreach ($initiativeId in $initiativeIdList) {
    if ($allInitiativeDefinitions.ContainsKey($initiativeId)) {
        $initiativeDefinition = $allInitiativeDefinitions.$initiativeId
        Write-Information "Processing initiative $initiativeId, $($initiativeDefinition.displayName)"

        $initiativeDefinitionParameters = $initiativeDefinition.parameters | ConvertTo-HashTable
        $initiativeParameters = Get-AzInitiativeParameters -definedParameters $initiativeDefinitionParameters

        $list += Get-AzPolicyEffectsForInitiative `
            -initiativeParameters $initiativeParameters `
            -initiativeDefinition $initiativeDefinition `
            -PolicyDefinitions $allPolicyDefinitions
    }
    else {
        Write-Error "Not found: initiative $initiativeId"    
    }
}

if (-not (Test-Path $outputPath)) {
    New-Item $outputPath -Force -ItemType directory
}

Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Generate comparison spreadsheet"
Write-Information "==================================================================================================="

# Hashtable to sort by Policy name
$byPolicyId = @{}
foreach ($item in $list) {
    $policyId = $item.policyId

    if (!$byPolicyId.ContainsKey($policyId)) {
        $byPolicyId.Add($policyId, @{
                policyDisplayName = $item.policyDisplayName
                policyDescription = $item.policyDescription
            }
        )
    }
    [hashtable] $policyEntry = $byPolicyId.$policyId
    $initiativeId = $item.initiativeId
    if ($policyEntry.ContainsKey($initiativeId)) {
        # Not prepared to handle
    }
    else {
        $initiativeEntry = @{
            paramValue                  = $item.paramValue
            allowedValues               = ((ConvertTo-Json $item.allowedValues -Compress) -replace '"', '""')
            defaultValue                = $item.defaultValue
            definitionType              = $item.definitionType
            initiativeParameterName     = $item.initiativeParameterName
            policyDefinitionReferenceId = $item.policyDefinitionReferenceId
            policyDefinitionGroupNames  = ((ConvertTo-Json $item.policyDefinitionGroupNames -Compress) -replace '"', '""')
        }
        $policyEntry.Add($initiativeId, $initiativeEntry)
    }
}

# Caching Initiative list and display names
[array] $cachedInitiativeList = @()
foreach ($initiativeId in $initiativeIdList) {
    if ($allInitiativeDefinitions.ContainsKey($initiativeId)) {
        $initiativeDefinition = $allInitiativeDefinitions.$initiativeId
        $quotedInitiativeDisplayName = $initiativeDefinition.displayName -replace '"', '""'
        $cachedInitiativeList += @{
            initiativeId                = $initiativeId
            quotedInitiativeDisplayName = $quotedInitiativeDisplayName
        }
    }
}

# Assemble Headers (2 Lines)
$header1 = "Policy,,,"
$header2 = "Display Name,Description,ID,"
$header1part = ""
$header2part = ""
$first = $true
foreach ($cachedInitiative in $cachedInitiativeList) {
    if ($first) {
        $first = $false # occupied by header1
    }
    else {
        $header1part += ","
    }
    $header2part += ",""$($cachedInitiative.quotedInitiativeDisplayName)"""
}
$header1 += ",Effect$header1part,Allowed Values$header1part,Parameter Name$header1part,Group Names$header1part,Reference ID$header1part"
$header2 += "$($header2part)$($header2part)$($header2part)$($header2part)$($header2part)"
$headers = [System.Collections.ArrayList]::new()
$null = $headers.Add($header1)
$null = $headers.Add($header2)

# Assemble rows
$rows = [System.Collections.ArrayList]::new()
foreach ($policyId in $byPolicyId.Keys) {
    $policyEntry = $byPolicyId.$policyId
    $quotedPolicyDisplayName = $policyEntry.policyDisplayName -replace '"', '""'
    $quotedPolicyDescription = $policyEntry.policyDescription -replace '"', '""'
    $effects = ""
    $alloweds = ""
    $groups = ""
    $references = ""
    $parameters = ""
    foreach ($cachedInitiative in $cachedInitiativeList) {
        $initiativeId = $cachedInitiative.initiativeId
        if ($policyEntry.ContainsKey($initiativeId)) {
            $initiativeEntry = $policyEntry.$initiativeId
            $effect = $initiativeEntry.paramValue
            $why = ($initiativeEntry.definitionType -eq "InititiativeDefaultValue") ? " - Initiative" : (($initiativeEntry.definitionType -eq "PolicyDefaultValue") ? " - Policy" : " - Static")
            $effects += ",$($effect)$($why)"
            $alloweds += ",""$($initiativeEntry.allowedValues)"""
            $groups += ",""$($initiativeEntry.policyDefinitionGroupNames)"""
            $references += ",$($initiativeEntry.policyDefinitionReferenceId)"
            $parameters += ",$($initiativeEntry.initiativeParameterName)"
        }
        else {
            $effects += ",_"
            $alloweds += ",_"
            $groups += ",_"
            $references += ",_"
            $parameters += ",_"
        }
    }
    $line = """$quotedPolicyDisplayName"",""$quotedPolicyDescription"",$policyId,_$($effects)$($alloweds)$($parameters)$($groups)$($references)"
    $null = $rows.Add($line)
}

[array] $output = $headers.ToArray() + ($rows.ToArray() | Sort-Object)

# Write file
$outputFilePath = "$($outputPath -replace '[/\\]$','')/$($initiativeSetSelector).compare.csv"
$output | Out-File $outputFilePath -Force


# Generate parmeters block per Initiative to be modified and used in assignment
Write-Information ""
Write-Information "==================================================================================================="
Write-Information "Generate parameter blocks per initiative"
Write-Information "==================================================================================================="

# Hashtable to sort by Initiative name
$byInitiativeId = @{}
foreach ($item in $list) {
    $initiativeId = $item.initiativeId
    if (!$byInitiativeId.ContainsKey($initiativeId)) {
        $byInitiativeId.Add($initiativeId, @{
                initiativeDisplayName = $item.initiativeDisplayName
                parameters            = @{}
                noParameterPolicyList = [System.Collections.ArrayList]::new()
            }
        )
    }
    [hashtable] $initiativeInfo = $byInitiativeId.$initiativeId
    [hashtable] $parameters = $initiativeInfo.parameters
    $initiativeParameterName = $item.initiativeParameterName
    if ($initiativeParameterName -ne "na") {
        if (-not ($parameters.ContainsKey($initiativeParameterName))) {
            # Avoid duplicate parameters used for multiple Policies
            $parameters.Add($initiativeParameterName, @{
                    value          = $item.paramValue
                    policy         = $item.policyDisplayName
                    definitionType = $item.definitionType
                    allowed        = (ConvertTo-Json $item.allowedValues -Compress)
                    single         = $true
                }
            )
        }
        else {
            $parameter = $parameters.$initiativeParameterName
            $parameter.single = $false
        }
    }
    else {
        $noParameterPolicyList = $initiativeInfo.noParameterPolicyList
        [void] $noParameterPolicyList.Add(@{
                policy         = $item.policyDisplayName
                value          = $item.paramValue
                definitionType = $item.definitionType
                allowed        = (ConvertTo-Json $item.allowedValues -Compress)
            }
        )
    }
}

# Write parameter blocks per Initiative
foreach ($initiativeId in $byInitiativeId.Keys) {
    [hashtable] $initiativeInfo = $byInitiativeId.$initiativeId
    $quotedInitiativeDisplayName = (($initiativeInfo.initiativeDisplayName -replace "[\\,/,\.,\-,\s,\[,:,\]]", "-") -replace "--", "-" -replace "^-", "")
    [hashtable] $parameters = $initiativeInfo.parameters
    $sb = [System.Text.StringBuilder]::new()
    [void] $sb.Append("{`n")
    $lastLineNumber = $parameters.Count
    $currentLineNumber = 1
    foreach ($parameterName in $parameters.Keys) {
        $parameter = $parameters.$parameterName
        $value = $parameter.value
        if ($parameter.single) {
            $policyDisplayName = $parameter.policy
            $line = "    // Policy '$policyDisplayName'`n"
            [void] $sb.Append($line)
            $line = ""
            if ($currentLineNumber -ge $lastLineNumber) {
                $line = "    ""$parameterName"": ""$value""`n"
            }
            else {
                $line = "    ""$parameterName"": ""$value"",`n"
            }
            [void] $sb.Append($line)
            $line = "        // '$($initiativeInfo.initiativeDisplayName)'`n"
            [void] $sb.Append($line)
            $line = "        // allowed=$($parameter.allowed)`n"
            [void] $sb.Append($line)
            [void] $sb.Append("`n")
        }
        else {
            if ($currentLineNumber -ge $lastLineNumber) {
                $line = "    ""$parameterName"": ""$value""`n"
            }
            else {
                $line = "    ""$parameterName"": ""$value"",`n"
            }
            [void] $sb.Append($line)
            $line = "        // '$($initiativeInfo.initiativeDisplayName)'`n"
            [void] $sb.Append($line)
            $line = "        // allowed=$($parameter.allowed)`n"
            [void] $sb.Append($line)
            [void] $sb.Append("`n")
        }
        ++$currentLineNumber
    }
    [void] $sb.Append("}`n")
            
    [array] $noParameterPolicyList = ($initiativeInfo.noParameterPolicyList).ToArray()
    if ($noParameterPolicyList.Length -gt 0) {
        [void] $sb.Append("//`n")
        [void] $sb.Append("// ************************************************************************************************`n")
        [void] $sb.Append("// $($noParameterPolicyList.Length) Policies without surfaced effect parameter:`n")
        [void] $sb.Append("// ************************************************************************************************`n")
        foreach ($noParameterPolicy in $noParameterPolicyList) {
            $line = "// $($noParameterPolicy.policy)`n"
            [void] $sb.Append($line)
            $line = "//     effect        = $($noParameterPolicy.value)`n"
            [void] $sb.Append($line)
            $line = "//     why           = $($noParameterPolicy.definitionType)`n"
            [void] $sb.Append($line)
            $line = "//     allowedValues = $($noParameterPolicy.allowed)`n"
            [void] $sb.Append($line)
            [void] $sb.Append("`n")
        }
    }

    # Write file
    $outputFilePath = "$($outputPath -replace '[/\\]$', '')/$quotedInitiativeDisplayName.parameters.jsonc"
    $sb.ToString() | Out-File $outputFilePath -Force
}