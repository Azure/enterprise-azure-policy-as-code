<#
.SYNOPSIS
    Exports a policy definition from Azure to a local file in the EPAC format
.DESCRIPTION
    Exports a policy definition from Azure to a local file in the EPAC format
.EXAMPLE
    New-EPACPolicyDefinition.ps1 -PolicyDefinitionId "/providers/Microsoft.Management/managementGroups/epac/providers/Microsoft.Authorization/policyDefinitions/Append-KV-SoftDelete" -OutputFolder .\

    Export the policy definition to the current folder. 
#>

[CmdletBinding()]

Param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$PolicyDefinitionId,
    [string]$OutputFolder
)

. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

if ($PolicyDefinitionId -match "Microsoft.Authorization/policyDefinitions") {
    $policyDefinition = Get-AzPolicyDefinition -Id $PolicyDefinitionId
    $baseTemplate = @{
        name       = $PolicyDefinition.name
        properties = $policyDefinition.Properties | Select-Object Description, DisplayName, Mode, Parameters, PolicyRule, @{n = "Metadata"; e = { $_.Metadata | Select-Object Version, Category } }
    }
    if ($OutputFolder) {
        $baseTemplate | ConvertTo-Json -Depth 50 | Out-File "$OutputFolder\$($policyDefinition.Name).json"
    }
    else {
        $baseTemplate | ConvertTo-Json -Depth 50
    }
}

if ($PolicyDefinitionId -match "Microsoft.Authorization/policySetDefinitions") {
    $policyDefinition = Get-AzPolicySetDefinition -Id $PolicyDefinitionId
    $baseTemplate = @{
        name       = $PolicyDefinition.Name
        properties = $policyDefinition.Properties | Select-Object Description, DisplayName, Mode, PolicyDefinitionGroups, Parameters, PolicyDefinitions, @{n = "Metadata"; e = { $_.Metadata | Select-Object Version, Category } }
    }
    $baseTemplate.properties.PolicyDefinitions | Foreach-Object {
        $_ | Add-Member -Type NoteProperty -Name policyDefinitionName -Value $_.policyDefinitionId.Split("/")[-1]
        $_.psObject.Properties.Remove('policyDefinitionId')
    }
    if ($OutputFolder) {
        $baseTemplate | ConvertTo-Json -Depth 50 | Out-File "$OutputFolder\$($policyDefinition.Name).json"
    }
    else {
        $baseTemplate | ConvertTo-Json -Depth 50
    }
}