#region parameters
param (
    [Parameter(Mandatory = $true)][string]$rootFolder,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$managementGroupName,
    [Parameter(Mandatory = $true)][string[]]$modifiedPolicies
)
#endregion

#region variables
# PolicyDef class is used to store hash table of policy varaiables
class PolicyDef {
    [string]$PolicyName
    [string]$PolicyDisplayName
    [string]$PolicyDescription
    [string]$PolicyMode
    [string]$PolicyMetaData
    [string]$PolicyRule
    [string]$PolicyParameters
}
#endregion

#region add policy function
function Add-Policies {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)][PolicyDef[]]$policies,
        [Parameter(Mandatory = $false)][String]$managementGroupName
    )

    $policyDefList = @()
    foreach ($policy in $Policies) {

        $createPolicy = @{
            "Name"        = $policy.PolicyName
            "Policy"      = $policy.PolicyRule
            "Parameter"   = $policy.PolicyParameters
            "DisplayName" = $policy.PolicyDisplayName
            "Description" = $policy.PolicyDescription
            "Metadata"    = $policy.PolicyMetadata
            "Mode"        = $policy.PolicyMode
        }

        if ($managementGroupName) {
            $mgObject = @{"ManagementGroupName" = $managementGroupName }
            
            $createPolicy += $mgObject
        }

        $policyName = $createPolicy.DisplayName

        Write-Host "##[debug] The following policy is being created/updated: $policyName"

        Write-Host ($createPolicy | Out-String)

        Write-Host "$createPolicy"


        New-AzPolicyDefinition @createPolicy

        Write-Host "##[debug] Policy definition for $policyName was created/updated..."

    }
}
#endregion

if ($modifiedPolicies -eq $null) {
    Write-Host "##vso[task.LogIssue type=warning;]No Policy diffs found or only deleted files found, skiping..."
}
else {

    Write-Host "##[section]Formatting list of policy folders... $modifiedPolicies"

    $policyList = @()

    foreach ($modifiedPolicy in $modifiedPolicies) {

        Write-Host "##[debug] File path: `"$modifiedPolicy`""
        $filePath = $rootFolder + $modifiedPolicy

        $azurePolicy = Get-Content $filePath | ConvertFrom-Json

        Write-Host "##[debug] Policy $($azurePolicy.properties.displayName)"

        #declare new policyDef object
        $policy = New-Object -TypeName PolicyDef

        #set Name variable
        if ($azurePolicy.name) {
            $policy.PolicyName = $azurePolicy.name
        }
        else {
            $policy.PolicyName = $azurePolicy.properties.displayName
        }

        #set Name variable
        $policy.PolicyDisplayName = $azurePolicy.properties.displayName
        $policy.PolicyDescription = $azurePolicy.properties.description
        $policy.PolicyMode = $azurePolicy.properties.mode
        $policy.PolicyMetadata = $azurePolicy.properties.metadata | ConvertTo-Json -Depth 100
        $policy.PolicyRule = $azurePolicy.properties.policyRule | ConvertTo-Json -Depth 100
        $policy.PolicyParameters = $azurePolicy.properties.parameters | ConvertTo-Json -Depth 100
        $policyList += $policy
    }

    #get list of policy folders
    Write-Host "##[section] Executing create policy..."

    $policyDefinitions = Add-Policies -Policies $policyList -ManagementGroupName $managementGroupName
}
#endregion