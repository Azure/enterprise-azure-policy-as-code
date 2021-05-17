# region parameters
param (
    [Parameter(Mandatory = $true)][string]$rootFolder,
    [Parameter(Mandatory = $true)][string[]]$modifiedInitiatives,
    [Parameter(Mandatory = $true)][string]$managementGroupName
)
#endregion

if ($modifiedInitiatives -eq $null) {
    Write-Host "##vso[task.LogIssue type=warning;]No Initiative diffs found or only deleted files found, skiping..."
}
else {
    # Inititaives list is not null or empty
    $azPD = Get-AzPolicyDefinition -ManagementGroupName $managementGroupName

    foreach ($modifiedInitiative in $modifiedInitiatives) {

        $filePath = $rootFolder + $modifiedInitiative

        Write-Host "##[debug] File path: $modifiedInitiative"

        $azureInitiative = Get-Content $filePath | ConvertFrom-Json

        Write-Host "##[debug] Initiative $($azureInitiative.properties.displayName)"

        $policyDefinitions = @()

        foreach ($policy in $azureInitiative.properties.PolicyDefinitions) {

            Write-Host "##[section] Processing $($policy.policyDefinitionName)"

            $policyLookup = $azPD | Where-Object { $_.Name -eq $policy.policyDefinitionName }

            if ($policyLookup) {
                #Write-Host "##[debug] Policy found setting policyID"
                #$policyLookup.ResourceId
            }
            else {
                Write-Host "##[error] Policy not found"
                throw
            }

            $pd = @{}
            $pd.policyDefinitionId = $policyLookup.ResourceId
            $pd.parameters = $policy.parameters
            $pd.policyDefinitionReferenceId = $policy.policyDefinitionReferenceId

            $policyDefinitions += $pd
        }

        $createInititative = @{}
        $createInititative = @{
            "Name"             = $azureInitiative.name
            "DisplayName"      = $azureInitiative.properties.displayName
            "Description"      = $azureInitiative.properties.description
            "Metadata"         = ($azureInitiative.properties.metadata | ConvertTo-Json -Depth 100)
            "Parameter"        = ($azureInitiative.properties.parameters | ConvertTo-Json -Depth 100)
            "PolicyDefinition" = (ConvertTo-Json @($policyDefinitions) -Depth 100)
            "GroupDefinition"  = (ConvertTo-Json @($azureInitiative.properties.policyDefinitionGroups) -Depth 100 )
        }


        if ((Get-AzSubscription).Count -gt 1) {
            Write-Host "##[debug] Adding Management Group to object..."
            $mgObject = @{"ManagementGroupName" = $managementGroupName }
            $createInititative += $mgObject
        }

        $initiativeName = $createInititative.Name

        Write-Host "##[debug] The following initiative is being created/updated:"
        Write-Host ($createInititative | Out-String)

        New-AzPolicySetDefinition @createInititative

        Write-Host "##[debug] Policy definition for $initiativeName was created/updated..."

    }
}