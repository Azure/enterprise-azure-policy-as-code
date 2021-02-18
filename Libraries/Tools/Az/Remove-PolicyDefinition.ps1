#region parameters
param (
    [Parameter(Mandatory=$true)][string]$scope
)
#endregion

$pds = Get-AzPolicyDefinition | Where-Object {$_.SubscriptionId -eq $scope -AND $_.Properties.policyType -eq "Custom"}

if (!$pds) {
    Write-Host "No policies found, exiting script"
    exit
}

foreach ($pd in $pds) {
    do {
        Write-Host "Removing $($pd.Properties.DisplayName)"

        #try to delete policy definition
        $rp = Remove-AzPolicyDefinition -ResourceID $pd.ResourceID `
                                  -Force `
                                  -ErrorVariable errorOuput `
                                  -ErrorAction SilentlyContinue

        #if assigned error
        if ($rp -eq $true) {
            Write-Output "Policy was removed"
        }
        elseif ($($errorOuput.CategoryInfo.Activity) -eq 'Remove-AzPolicyDefinition') {

            $errorMessage = (($errorOuput.Exception.Message).Split("'"))[3]
        
            if ($errorMessage -like "/subscription*") {
                Write-Host "Removing assignmentID: $($errorMessage)"

                $ra = Remove-AzPolicyAssignment -Id $errorMessage

                if ($ra-eq $true) {
                    Write-Host "Assignment was removed"
                }
                else {
                    Write-Host "Error: Assignment was NOT removed"
                    throw
                }
            }
        }
        else {
            Write-Output "Error not related to assignement"

            $errorOuput

            throw
        }

    } until (!$errorOuput)
}