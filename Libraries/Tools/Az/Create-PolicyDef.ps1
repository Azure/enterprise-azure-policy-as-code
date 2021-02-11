#region parameters
param (
    [Parameter(Mandatory=$true)][string]$rootFolder,
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$managementGroupName,
    [Parameter(Mandatory=$true)][string[]]$modifiedPolicies
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

#region get policy function
function Get-Policies {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)][string[]]$modifiedPolicies,
        [Parameter(Mandatory = $true)][string]$rootDir
    )

    $policyList = @()

    foreach ($modifiedPolicy in $modifiedPolicies) {

        Write-Host "##[debug] File path: .$rootDir."
        Write-Host "##[debug] File path: .$modifiedPolicy."

        $filePath = $rootDir+ "/" + $modifiedPolicy + "azurepolicy.json"

        Write-Host "##[debug] File path: $filePath"

        $azurePolicy = Get-Content $filePath | ConvertFrom-Json

        Write-Host "##[debug] Policy $($azurePolicy.properties.displayName)"

        #declare new policyDef object
        $policy = New-Object -TypeName PolicyDef

        #set variables
        $policy.PolicyName = $azurePolicy.properties.displayName
        $policy.PolicyDisplayName = $azurePolicy.properties.displayName
        $policy.PolicyDescription = $azurePolicy.properties.description
        $policy.PolicyMode = $azurePolicy.properties.mode
        $policy.PolicyMetadata = $azurePolicy.properties.metadata | ConvertTo-Json -Depth 100
        $policy.PolicyRule = $azurePolicy.properties.policyRule | ConvertTo-Json -Depth 100
        $policy.PolicyParameters = $azurePolicy.properties.parameters | ConvertTo-Json -Depth 100
        $policyList += $policy
    }

    return $policyList
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
            "Name" = $policy.PolicyName
            "Policy" = $policy.PolicyRule
            "Parameter" = $policy.PolicyParameters
            "DisplayName" = $policy.PolicyDisplayName
            "Description" = $policy.PolicyDescription
            "Metadata" = $policy.PolicyMetadata
            "Mode" = $policy.PolicyMode
        }

        if ($managementGroupName) {
            $mgObject = @{"ManagementGroupName" = $managementGroupName}
            
            $createPolicy += $mgObject
        }

        $policyName = $createPolicy.DisplayName

        Write-Host "##[debug] The following policy is being created/updated:"

        Write-Host ($createPolicy | Out-String)

        New-AzPolicyDefinition @createPolicy

        Write-Host "##[debug] Policy definition for $policyName was created/updated..."

    }
}
#endregion

Write-Host "##[section]Formatting list of policy folders..."

#get list of policy folders
$policies = Get-Policies -modifiedPolicies $modifiedPolicies `
                         -rootDir $rootFolder 

Write-Host "    ##[debug] Names:" $policies.PolicyName
Write-Host "    ##[debug] Count:" $policies.count

Write-Host "##[section] Executing create policy..."

$policyDefinitions = Add-Policies -Policies $policies `
                                  -ManagementGroupName $managementGroupName
#                                  -ManagementGroupName $managementGroup.Name
#endregion