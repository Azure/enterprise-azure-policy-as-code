function Get-HydrationUserObjectId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $Output = "./Output"
    )
    # TODO: Logging
    $debugLogContents = & { Connect-AzAccount -Force -Debug -TenantId $(Get-AzContext).Tenant.Id -SubscriptionId $(Get-AzContext).Subscription.Id -AccountId $(Get-AzContext).Account.Id -Confirm:$False } *>&1
    $accountId = ""
    $jsonObject = ""
    foreach ($line in $debugLogContents) {
        if ($line -match ".*wam_telemetry.*") {
            if ($debug) {
                #TODO: Logging which line is being evaluated
            }
            if ($matches[0] -match "Value: (.*)") {
                if ($debug) {
                    #TODO: Logging which match is being evaluated
                }
                #TODO: If null then throw/log error
                $jsonObject = ($matches[1] | convertfrom-json -depth 100)
                #TODO: If null then throw/log error
                $accountId = $jsonObject.account_id
                #TODO: If null then throw/log error
                if ($debug) {
                    #TODO: Logging compressed json object
                }
                break
            }
        }
        #TODO: If null then throw/log error
    }
    if (-not [string]::IsNullOrEmpty($accountId)) {
        #TODO: Logging success value
        #TODO: Logging success status
        return $accountId
    }
    else {
        if ($debug -and (-not [string]::IsNullOrEmpty($jsonObject))) {
            #TODO Add error information that json object was empty
        }
        throw "Failed to retrieve the account id from the Connect-AzAccount debug log.`nConfirm active connection, and if this is confirmed then run with the -debug flag for additional logging information."
    }
}