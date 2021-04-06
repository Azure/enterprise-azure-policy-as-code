# region parameters
param (
    [Parameter(Mandatory=$true)][string]$rootFolder,
    [Parameter(Mandatory=$true)][string[]]$assignmentNames,
    # location of policies and initiatives
    [Parameter(Mandatory=$true)][string]$definitionLocation
)
#endregion

# evaluate $definitionLocation
# if subscription, lookup sub GUID
# if managementgroup, lookup GUID for Tenant Root Group or name for other

# default to tentant root group

function Trim-Length {
    param (
        [parameter(Mandatory=$True,ValueFromPipeline=$True)] [string] $Str
      , [parameter(Mandatory=$True,Position=1)] [int] $Length
    )
        
        $Str[($Str.Length-24)..($Str.Length-1)] -join ""

}

foreach ($assignmentName in $assignmentNames) {

    $assignmentPath = $RootFolder + "\Assignments\" + $assignmentName + ".json"

    Write-Host "##[section] Creating $assignmentName Policy/Initiative"
    Write-Host "##[debug]     Assignment Def Path: $assignmentPath"

    #region processing scope

    $assignmentDef = Get-Content -Path $assignmentPath | ConvertFrom-Json

    # get managementgroupID or subscriptionID (formated correctly)
    switch ($assignmentDef.scope.type){
        'Management Group' {$scope = (Get-AzManagementGroup -GroupName $assignmentDef.scope.name).Id; break}
        'Subscription' {$scope = "/subscriptions/$((Get-AzSubscription -SubscriptionName $assignmentDef.scope.name).Id)"; break}
    }

    Write-Host "##[debug]     Assignment Scope: $scope"

    #endregion

    #region all policies and initiatives

    $azPD = Get-AzPolicyDefinition -ManagementGroupName $definitionLocation
    $azID = Get-AzPolicySetDefinition -ManagementGroupName $definitionLocation

    #endregion

    #region processing policies
    foreach ($policy in $assignmentDef.policies) {

        $policyLookup = $azPD | Where-Object {$_.Name -eq $policy.Name}

        $policyName = $policyLookup.Name

        if ($policyName) {
            Write-Host "##[section] Processing $policyName"
        }
        else {
            Write-Host "Policy not found"
        }
    }
    #endregion

    #region processing initiatives
    foreach ($initiative in $assignmentDef.initiatives) {

        $initiativeParameter = @{}

        "##[section] Processing $($initiative.initiativeName)"

        $initiativeLookup = $azID | Where-Object {$_.Properties.DisplayName -eq $($initiative.initiativeName)}

        $initiativeName = $initiativeLookup.Name

        $initiativeDisplayName = $initiativeLookup.Properties.DisplayName

        if ($initiativeName) {
            Write-Host "##[debug]       Found $initiativeName"

            $initParam = $initiativeLookup.Properties.Parameters

            foreach ($param in $initParam) {
                Write-Host "##[debug]       Processing Param"
            }
            
            if ($initiativeLookup.Properties.Parameters) {
                Write-Host "##{debug}       Processing Parameters"
            }
            else {
                Write-Host "##{debug}       Initiative has no Parameters"
            }

            $initiativeName

            $initiativeLookup

            $scope

            $initiativeParameter

            New-AzPolicyAssignment -Name ($initiativeName | Trim-Length 24) `
                                -DisplayName $initiativeDisplayName `
                                -PolicySetDefinition $initiativeLookup `
                                -Scope $scope `
                                -PolicyParameterObject $initiativeParameter
        }
        else {
            Write-Host "##[error]       Initiative not found"
        }
    }
    #endregion
}
