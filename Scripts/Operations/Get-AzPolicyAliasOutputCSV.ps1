<#
.SYNOPSIS
    Gets all aliases and outputs them to a CSV file.
#>

[System.Collections.ArrayList] $allRows = [System.Collections.ArrayList]::new()
$aliasesByResourceType = Get-AzPolicyAlias | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable

foreach ($resourceTypeEntry in $aliasesByResourceType) {
    $Namespace = $resourceTypeEntry.Namespace
    $resourcetype = $resourceTypeEntry.ResourceType
    foreach ($alias in $resourceTypeEntry.Aliases){
        $rowObj = [ordered]@{
            namespace    = $Namespace
            resourcetype = $resourcetype
            propertyAlias      = $alias.Name
        }
        $null = $allRows.Add($rowObj)
    }
}
$allRows | ConvertTo-Csv | Out-File 'FullAliasesOutput.csv' -Force
