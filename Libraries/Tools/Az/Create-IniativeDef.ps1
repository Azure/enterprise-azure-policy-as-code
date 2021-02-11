# region parameters
param (
    [Parameter(Mandatory=$true)][string]$rootFolder,
    [Parameter(Mandatory=$true)][string[]]$modifiedInitiatives,
    [Parameter(Mandatory=$true)][string]$managementGroupName
)
#endregion

$azPD = Get-AzPolicyDefinition

foreach ($modifiedInitiative in $modifiedInitiatives) {

    $filePath = $rootFolder + "\Initiatives\" + $modifiedInitiative + ".json"

    Write-Host "##[debug] File path: $filePath"

    $azureInitiative = Get-Content $filePath | ConvertFrom-Json

    Write-Host "##[debug] Policy $($azureInitiative.properties.displayName)"

    $policyDefinitions = @()

    foreach ($policy in $azureInitiative.properties.PolicyDefinitions) {

        Write-Host "##[section] Processing $($policy.policyDefinitionName)"

        $policyLookup = $azPD | Where-Object {$_.Name -eq $policy.policyDefinitionName}

        if($policyLookup){
            Write-Host "##[debug] Policy found setting policyID"

            $policyLookup.ResourceId
        }
        else {
            Write-Host "##[error] Policy not found"

            throw
        }

        $pd = @{}

        $pd.policyDefinitionId = $policyLookup.ResourceId
        $pd.parameters = $policy.parameters
        $pd.policyDefinitionReferenceId = $policy.policyDefinitionReferenceId

        $pd

        $policyDefinitions += $pd
    }

    $createInititative = @{}

    $createInititative = @{
        "Name" = $azureInitiative.name
        "DisplayName" = $azureInitiative.properties.displayName
        "Description" = $azureInitiative.properties.description
        "Metadata" = ($azureInitiative.properties.metadata | ConvertTo-Json -Depth 100)
        "Parameter" = ($azureInitiative.properties.parameters | ConvertTo-Json -Depth 100)
        "PolicyDefinition" = ($policyDefinitions | ConvertTo-Json -Depth 100 -AsArray)
        "GroupDefinition" = ($azureInitiative.properties.policyDefinitionGroups | ConvertTo-Json -Depth 100 -AsArray)
    }

    if((Get-AzSubscription).Count -gt 1) {
        Write-Host "##[debug] Adding Management Group to object..."

        $mgObject = @{"ManagementGroupName" = $managementGroupName}
        
        $createInititative += $mgObject
    }

    $initiativeName = $createInititative.Name

    Write-Host "##[debug] The following initiative is being created/updated:"

    Write-Host ($createInititative | Out-String)

    New-AzPolicySetDefinition @createInititative

    Write-Host "##[debug] Policy definition for $initiativeName was created/updated..."

}