<#
.SYNOPSIS
    Gets all aliases and outputs them to a CSV file.
#>

[System.Collections.ArrayList] $allRows = [System.Collections.ArrayList]::new()
$aliasesByResourceType = Get-AzPolicyAlias | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashTable

foreach ($resourceTypeEntry in $aliasesByResourceType) {
    $namespace = $resourceTypeEntry.Namespace
    $resourcetype = $resourceTypeEntry.ResourceType
    foreach ($alias in $resourceTypeEntry.Aliases){
        $rowObj = [ordered]@{
            namespace    = $namespace
            resourcetype = $resourcetype
            propertyAlias      = $alias.Name
        }
        $null = $allRows.Add($rowObj)
    }
}
$allRows | ConvertTo-Csv | Out-File 'FullAliasesOutput.csv' -Force
