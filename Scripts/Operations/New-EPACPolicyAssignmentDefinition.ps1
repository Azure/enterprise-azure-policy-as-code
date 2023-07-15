<#
.SYNOPSIS
    Exports a policy assignment from Azure to a local file in the EPAC format
.DESCRIPTION
    Exports a policy assignment from Azure to a local file in the EPAC format
.EXAMPLE
    New-EPACPolicyAssignmentDefinition.ps1 -PolicyDefinitionId "/providers/Microsoft.Management/managementGroups/epac/providers/Microsoft.Authorization/policyDefinitions/Append-KV-SoftDelete" -OutputFolder .\

    Export the Policy to the current folder.
#>

[CmdletBinding()]

Param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$PolicyAssignmentId,
    [string]$OutputFolder
)

. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

$PolicyAssignment = Get-AzPolicyAssignment -Id $PolicyAssignmentId
if ($PolicyAssignment) {
    if ($PolicyAssignment.Properties.PolicyDefinitionId -match "Microsoft.Authorization/policyDefinitions") {
        $baseTemplate = @{
            assignment      = @{
                name        = $PolicyAssignment.Name
                displayName = $PolicyAssignment.Properties.DisplayName
                description = $PolicyAssignment.Properties.Description
            }
            definitionEntry = @{
                policyName = $PolicyAssignment.Properties.PolicyDefinitionId.Split("/")[-1]
            }
            parameters      = @{} | ConvertTo-HashTable
        }
        ($PolicyAssignment.Properties.Parameters | ConvertTo-HashTable).GetEnumerator() | ForEach-Object {
            $baseTemplate.parameters.Add($_.Name, $_.Value.Value)
        }
        if ($OutputFolder) {
            $baseTemplate | ConvertTo-Json -Depth 50 | Out-File "$OutputFolder\$($policyAssignment.Name).json"
        }
        else {
            $baseTemplate | ConvertTo-Json -Depth 50
        }
    }
    elseif ($PolicyAssignment.Properties.PolicyDefinitionId -match "Microsoft.Authorization/policySetDefinitions") {
        $baseTemplate = @{
            assignment      = @{
                name        = $PolicyAssignment.Name
                displayName = $PolicyAssignment.Properties.DisplayName
                description = $PolicyAssignment.Properties.Description
            }
            definitionEntry = @{
                policySetName = $PolicyAssignment.Properties.PolicyDefinitionId.Split("/")[-1]
            }
            parameters      = @{} | ConvertTo-HashTable
        }
        ($PolicyAssignment.Properties.Parameters | ConvertTo-HashTable).GetEnumerator() | ForEach-Object {
            $baseTemplate.parameters.Add($_.Name, $_.Value.Value)
        }
        if ($OutputFolder) {
            $baseTemplate | ConvertTo-Json -Depth 50 | Out-File "$OutputFolder\$($policyAssignment.Name).json"
        }
        else {
            $baseTemplate | ConvertTo-Json -Depth 50
        }
    }
}
