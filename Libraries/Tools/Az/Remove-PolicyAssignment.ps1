# region parameters
param (
    [Parameter(Mandatory=$true)][string]$rootFolder,
    [Parameter(Mandatory=$true)][string]$assignmentName
)
#endregion

$assignmentPath = $RootFolder + "\Assignments\" + $assignmentName + ".json"

Write-Host "##[section] Creating $assignmentName Policy/Initiative"
Write-Host "##[debug]     Assignment Def Path: $assignmentPath"

$assignmentDef = Get-Content -Path $assignmentPath | ConvertFrom-Json

switch ($assignmentDef.scope.type){
    'Management Group' {$scope = Get-AzManagementGroup -Name $assignmentDef.scope.name; break}
    'Subscription' {$scope = Get-AzSubscription -SubscriptionName $assignmentDef.scope.name; break}
}

Write-Host "##[debug]     Remove Scope: $scope"

$scopeId = $scope.id

$scope = "/subscriptions/$scopeId"

Write-Host "Looking up policies and initiative at the Tenant Root Group scopes"

$azPD = Get-AzPolicyDefinition -ManagementGroupName "4cb791f1-02d1-4a4e-8610-911ee57bb08c"
$azID = Get-AzPolicySetDefinition -ManagementGroupName "4cb791f1-02d1-4a4e-8610-911ee57bb08c"

#region processing initiatives
foreach ($initiative in $assignmentDef.initiatives) {

    $initiativeName = $initiative.initiativeName

    "##[section] Processing $initiativeName"

    $initiativeLookup = $azID | Where-Object {$_.Name -eq $initiativeName}

    $initiativeName = $initiativeLookup.Name

    if ($initiativeName) {
        Write-Host "##[debug]       Found $initiativeName"

        $assignment = Get-AzPolicyAssignment -Name $initiativeName `
                                             -Scope $scope
        
        if ($assignment) {
            Write-Host "##{debug}       Rolling back assignment"

            Remove-AzPolicyAssignment -Name $initiativeName `
                                      -Scope $scope

        }
        else {
            Write-Host "##{debug}       Initiative not assigned at scope: $scope"
        }
    }
    else {
        Write-Host "##[debug]       Initiative not found"
    }
}
#endregion