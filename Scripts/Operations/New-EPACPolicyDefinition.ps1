<#
.SYNOPSIS
    Exports a Policy definition from Azure to a local file in the EPAC format
.DESCRIPTION
    Exports a Policy definition from Azure to a local file in the EPAC format
.EXAMPLE
    New-EPACPolicyDefinition.ps1 -PolicyDefinitionId "/providers/Microsoft.Management/managementGroups/epac/providers/Microsoft.Authorization/policyDefinitions/Append-KV-SoftDelete" -OutputFolder .\

    Export the Policy definition to the current folder.
#>

[CmdletBinding()]

Param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$PolicyDefinitionId,
    [string]$OutputFolder
)

if ($PolicyDefinitionId -match "Microsoft.Authorization/policyDefinitions") {
    $PolicyDefinition = Get-AzPolicyDefinition -Id $PolicyDefinitionId
    $baseTemplate = [ordered]@{
        name       = $PolicyDefinition.name
        properties = $PolicyDefinition.Properties | Select-Object DisplayName, Mode, Description, @{n = "Metadata"; e = { $_.Metadata | Select-Object Version, Category } }, Parameters, PolicyRule
    }
    if ($OutputFolder) {
        $baseTemplate | ConvertTo-Json -Depth 50 | Out-File "$OutputFolder\$($PolicyDefinition.Name).json"
    }
    else {
        $baseTemplate | ConvertTo-Json -Depth 50
    }
}
elseif ($PolicyDefinitionId -match "Microsoft.Authorization/policySetDefinitions") {
    $PolicyDefinition = Get-AzPolicySetDefinition -Id $PolicyDefinitionId
    $baseTemplate = [ordered]@{
        name       = $PolicyDefinition.Name
        properties = $PolicyDefinition.Properties | Select-Object DisplayName, Description, @{n = "Metadata"; e = { $_.Metadata | Select-Object Version, Category } }, PolicyDefinitionGroups, Parameters, PolicyDefinitions
    }
    $baseTemplate.properties.PolicyDefinitions | Foreach-Object {
        $_ | Add-Member -Type NoteProperty -Name policyDefinitionName -Value $_.policyDefinitionId.Split("/")[-1]
        $_.psObject.Properties.Remove('policyDefinitionId')
    }
    if ($OutputFolder) {
        $baseTemplate | ConvertTo-Json -Depth 50 | Out-File "$OutputFolder\$($PolicyDefinition.Name).json"
    }
    else {
        $baseTemplate | ConvertTo-Json -Depth 50
    }
}
