# region parameters
param (
    #list of policy names to be in the initiative
    [Parameter(Mandatory=$true)][string]$defInitFile,
    [Parameter(Mandatory=$false)][string]$managementGroupName = "4cb791f1-02d1-4a4e-8610-911ee57bb08c"
)
#endregion

$managementGroupName

$azPD = Get-AzPolicyDefinition -ManagementGroupName $managementGroupName

$initiativePolicies = Get-Content -Path $defInitFile | ConvertFrom-Json

$initiativeDef = @()
$initiativeDefMeta = @()
$initiativeDefGlobal = @()
$initiativeDefPolicies = @()

$y = "" |Select effect
$y.effect = "[parameters('effect')]"

$initiativeDefGlobal += $y

$x = "" | Select initiativeName,metadata,globalParameters,policies
$x.initiativeName = ""
$x.metadata = $initiativeDefMeta
$x.globalParameters = $initiativeDefGlobal

foreach ($initiativepolicy in $initiativePolicies.policyName) {

    $initiativepolicy

    $pd = $azPD | Where-Object {$_.Name -eq $initiativepolicy -or $_.Properties.displayname -eq $initiativepolicy}

    $policy = @{}
    $policy.Name = $initiativepolicy
    $policy.parameters = @{}

    $parameterNames = ($pd.Properties.parameters | Get-Member -MemberType NoteProperty).Name

    foreach ($param in $parameterNames) {

#        if($x.globalParameters -match $param){
#            Write-Host "Parameter set as global"
#        }
#        else {
            $policy.parameters.$param = @{}

            $pd.Properties.parameters.$param.type
    
            $policy.parameters.$param.value = $pd.Properties.parameters.$param.defaultValue
#        }
    }

    $initiativeDefPolicies += $policy
}

$x.policies = $initiativeDefPolicies

$initiativeDef += $x

$initiativeDef | ConvertTo-Json -Depth 100 -AsArray