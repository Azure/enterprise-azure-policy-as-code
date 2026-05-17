function Test-HydrationAccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("path", "rbacHydration", "rbacEpacDeploy", "rbacPolicyDeploy", "rbacRoleDeploy", "graphAccess", `
                "internetConnection", "azureConnectivity", "azureConnection")]
        [string]
        $TestType,
        [Parameter(Mandatory = $false)]
        [string]
        $TestedValue,
        [Parameter(Mandatory = $true)]
        [string]
        $LogFilePath,
        [Parameter(Mandatory = $false)]
        [string]
        $RbacRestApiVersion = "2022-04-01",
        [Parameter(Mandatory = $false)]
        [string]
        $RbacClientId,
        [switch]
        $UseUtc = $false,
        [switch]
        $Silent
    )
    # NOTE: (for helpfile) Managed IDs use the Obect (Principal) ID from GUI.
    if ($DebugPreference -eq "Continue" -or $debug) {
        $debug = $true
        $debugPreference = "Continue"
        Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType logEntryDataAsPresented -EntryData "Debugging Enabled for Test-HydrationAccess" -UseUtc:$UseUtc -Silent
    }
    $rolesTested = @{
        Owner                               = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
        Contributor                         = "b24988ac-6180-42a0-ab88-20f7382dd24c"
        Reader                              = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
        ResourcePolicyContributor           = "36243c78-bf99-498c-9df9-86d9f8d28608"
        RoleBasedAccessControlAdministrator = "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    }
    $testData = [ordered]@{
        name              = ""
        description       = ""
        result            = ""
        evaluation        = ""
        customReturn      = ""
        message           = ""
        useStandardOutput = $true
    }
    if (!(Test-Path (Split-Path $LogFilePath))) {
        $null = New-Item -Path (Split-Path $LogFilePath) -ItemType Directory -Force
    }
    # TODO: Revisit a better way to manage the error handling here with try/catch/stop etc. to obviate the need for the error.clear() method.
    # Write-Warning "Service Principals are untested as of now, will be tested before release."
    switch ($TestType) {
        "path" {
            # Set prerequisite test information
            $testData.name = "Path test for $(Split-Path $TestedValue -Leaf)"
            $testData.description = "Confirming that the path $TestedValue exists."
            $testData.message = "Local path data access test: $(Split-Path $TestedValue -Leaf)"

            # Log test initiation
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "testStart" -EntryData "$($testData.name)`: $($testData.description)" -UseUtc:$UseUtc -Silent

            # Add command to log file for debug purposes
            if ($debug) {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "commandStart" -EntryData "Test-Path $TestedValue" -UseUtc:$UseUtc
            }
            $Error.Clear()
            $testData.evaluation = Test-Path $TestedValue
            if ($Error[0].Exception.Message) {
                $errorMessage = $Error[0].Exception.Message
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Error - $errorMessage" -UseUtc:$UseUtc
            }
            # Evaluate Return (it is true/false binary)
            if ($testData.evaluation -eq $true) {
                # $testData.evaluation = "Passed"
                $testData.message = "$TestedValue exists"
            }
            else {
                $testData.message = "$TestedValue does not exist"
            }
        }
        "graphAccess" {
            # Set prerequisite test information
            $testData.name = "Azure Resource Graph Access Validation Test"
            $testData.description = "This will test access to Azure Resource Graph by querying for subscriptions. The presence of subscriptions in the Tenant is not a prerequisite for success."
            $testData.message = "Azure Resource Graph data access test"
            if (!($TestedValue)) {
                $queryString = "ResourceContainers | where type == 'microsoft.resources/subscriptions'"
            }
            else {
                $queryString = $TestedValue
            }
            

            # Log test initiation
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "testStart" -EntryData "$($testData.name)`: $($testData.description)" -UseUtc:$UseUtc

            # Add command to log file for debug purposes
            if ($debug) {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "commandStart" -EntryData "Search-AzGraphAllItems -Query $queryString -ProgressItemName `"Subscriptions`"" -UseUtc:$UseUtc
            }

            # Clear error messages to clarify error output, and run test
            $Error.Clear()
            $testData.evaluation = Search-AzGraphAllItems -Query $queryString -ProgressItemName "Subscriptions"

            # If the return was $false or null, check for any error messages that may have occurred
            if (!($testData.evaluation)) {
                $errorMessage = $Error[0].Exception.Message | Out-Null
                $testData.Message = "No Subscriptions found in Tenant, verify RBAC Access of read or greater for Subscription and Management Group objects and permission to use Azure Resource Graph."
            }
            else {
                $testData.Message = "Azure Resource Graph test successful"
            }
        }
        "internetConnection" {
            # Set prerequisite test information
            if (!($TestedValue)) {
                $TestedValue = "www.microsoft.com"
            }
            $testData.name = "Internet Connectivity Validation Test"
            $testData.description = "This will test connectivity to the internet by pinging $TestedValue"
            $testData.Message = "Internet ping test"
            
            # Log test initiation
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "testStart" -EntryData "$($testData.name)`: $($testData.description)" -UseUtc:$UseUtc -Silent:$Silent

            # Add command to log file for debug purposes

            if ($debug) {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "commandStart" -EntryData "Test-Connection -ComputerName $TestedValue -Count 3 -Quiet" -UseUtc:$UseUtc
            }
    
            # Clear error messages to clarify error output, and run test
            $Error.Clear()
            $testData.evaluation = Test-Connection -ComputerName $TestedValue -Count 3 -Quiet
            # If the return was $false or null, check for any error messages that may have occurred
            if (!($testData.evaluation)) {
                $errorMessage = $Error[0].Exception.Message | Out-Null
                $testData.Message = "$TestedValue ping test failed, verify ip, dns, and firewall settings."
            }
            else {
                $testData.Message = "$TestedValue ping test successful"
            }
        }
        "rbacHydration" {
            $rbacTest = [ordered]@{
                Owner                               = "Skipped"
                Contributor                         = "Skipped"
                Reader                              = "Skipped"
                ResourcePolicyContributor           = "Skipped"
                RoleBasedAccessControlAdministrator = "Skipped"
            }
            
            if (!($TestedValue)) {
                $scope = -join ("/providers/Microsoft.Management/managementGroups/", $(Get-AzContext).Tenant.Id)
            }
            else {
                $scope = -join ("/providers/Microsoft.Management/managementGroups/", $TestedValue)
            }
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType logEntryDataAsPresented -EntryData "Scope: $scope" -UseUtc:$UseUtc -Silent:$Silent
            if ($RbacClientId) {
                $guidPattern = '^[{(]?[0-9a-fA-F]{8}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{4}[-]?[0-9a-fA-F]{12}[)}]?$'
                if (!($RbacClientId -match $guidPattern)) {
                    Write-Error "The ClientId provided is not a valid GUID. Please provide a valid GUID for the ClientId parameter. To use the Hydration Kit to gather this information, Run Connect-AzAccount to connect as that user, and run Get-HydrationUserObjectId to retrieve the GUID."
                }
                else {
                    $clientId = $RbacClientId
                }
            } 
            else {
                # Get ClientId from current context
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Determining account type used for current connection...." -UseUtc:$UseUtc -Silent
                if ($((Get-AzContext).Account.Type) -eq "ServicePrincipal") {
                    Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryasPresented" -EntryData "Account Type: ServicePrincipal" -UseUtc:$UseUtc
                    if ($debug) {
                        $testCommand = "(Get-AzContext).Account.Type"
                        Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "commandStart" -EntryData "$testCommand" -UseUtc:$UseUtc
                        Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryasPresented" -EntryData "Account Type: ServicePrincipal" -UseUtc:$UseUtc
                    }
                    $clientId = (Get-AzContext).Account.Id
                }
                elseif ($((Get-AzContext).Account.Type) -eq "User") {
                    if ($debug) {
                        $testCommand = "Get-HydrationUserObjectId"
                        Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "commandStart" -EntryData "$testCommand" -UseUtc:$UseUtc
                        Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryasPresented" -EntryData "Account Type: User" -UseUtc:$UseUtc
                    }
                    $Error.Clear()
                    try {
                        $clientId = Get-HydrationUserObjectId
                    }
                    catch {
                        $errorMessage = $_.Exception.Message
                        Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Error - $errorMessage" -UseUtc:$UseUtc
                        Write-Error $errorMessage
                    }
                }
            }
            $testData.name = "Hydration Kit RBAC Access Test"
            $testData.description = "Reviewing RBAC Permissions for $clientId."
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType testStart -EntryData "$($testData.name)`: $($testData.description)" -UseUtc:$UseUtc -Silent:$Silent
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "ClientId`: $clientId" -UseUtc:$UseUtc -Silent:$Silent
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Gathering RBAC entries at $scope and reviewing entries for $clientId...." -UseUtc:$UseUtc -Silent
            if ($debug) {
                $testCommand = "Get-AzRoleAssignmentsRestMethod -Scope $((Get-AzContext).Tenant.Id) -ApiVersion $RbacRestApiVersion"
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "commandStart" -EntryData "$testCommand" -UseUtc:$UseUtc -Silent:$Silent
            }
            try {
                $Error.Clear()
                $rbac = Get-AzRoleAssignmentsRestMethod -Scope $scope -ApiVersion $RbacRestApiVersion
            }
            catch {
                $errorMessage = $_.Exception.Message
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Error - $errorMessage" -UseUtc:$UseUtc -Silent:$Silent
                switch -Wildcard ($errorMessage) {
                    "*error occurred while sending the req*" {
                        Write-Error "An error occurred while attempting to gather RBAC data. This is generally indicative of a failed authorization attempt."
                    }
                    default {
                        Write-Error $errorMessage
                    }
                }
                return "Failed"
            }            
            if ($debug) {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "RBAC Data: $($rbac | ConvertTo-Json -Depth 100 -Compress) -UseUtc:$UseUtc" -Silent:$Silent
            }
            try {
                $Error.Clear()
                $rbacSubset = $rbac | Where-Object { $_.properties.principalId -eq $clientId }   
            }
            catch {
                $errorMessage = $_.Exception.Message
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Error - $errorMessage" -UseUtc:$UseUtc -Silent:$Silent
                Write-Error $errorMessage
                return "Failed"
            }
            if ($debug) {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "$clientId RBAC Data: $($rbacSubset | ConvertTo-Json -Depth 100 -Compress)" -UseUtc:$UseUtc -Silent:$Silent
            }
            foreach ($key in $rolesTested.keys) {
                $rbacRolesFound = $rbacSubset | Where-Object { $_.properties.roleDefinitionId -like "*$($rolesTested[$key])" }
                if ($rbacRolesFound) {
                    $rbacTest.$key = "Passed"
                }
                else {
                    $rbacTest.$key = "Failed"
                }
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Test for Role: $key -- $($rbacTest.$key)" -UseUtc:$UseUtc -Silent
            }
            # Test return against required configurations
            $rolesTested = @{
                Owner                               = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
                Contributor                         = "b24988ac-6180-42a0-ab88-20f7382dd24c"
                Reader                              = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
                ResourcePolicyContributor           = "36243c78-bf99-498c-9df9-86d9f8d28608"
                RoleBasedAccessControlAdministrator = "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
            }
            if (($rbacTest.Owner -eq "Passed") -or ($rbacTest.Contributor -eq "Passed" -and $rbacTest.RoleBasedAccessControlAdministrator -eq "Passed")) {
                $testData.evaluation = "Passed"
                $testData.customReturn = "PassedHydrationDeploy"
                $testData.message = "This security principal has significant rights in Azure, and is overprovisioned for pipeline operations; however, is appropriate for the EPAC Hydration Kit."
            }
            elseif ($rbacTest.ResourcePolicyContributor -eq "Passed" -and $rbacTest.RoleBasedAccessControlAdministrator -eq "Passed") {
                $testData.evaluation = "Passed"
                $testData.customReturn = "PassedEpacAllDeploy"
                $testData.message = "This security principal can be used for both Deploy-PolicyPlan operations and Deploy-RolesPlan operations. This is appropriate for initial deployments, but is overprovisioned for pipeline use."
            }
            elseif ($rbacTest.ResourcePolicyContributor -eq "Passed") {
                $testData.evaluation = "Passed"
                $testData.customReturn = "PassedEpacPolicyDeploy"
                $testData.message = "This security principal should only be used for Deploy-PolicyPlan operations, and is appropriate for Pipeline Operations."
            }
            elseif ($rbacTest.RoleBasedAccessControlAdministrator -eq "Passed") {
                $testData.evaluation = "Passed"
                $testData.customReturn = "PassedEpacRoleDeploy"
                $testData.message = "This security principal should only be used for Deploy-RolesPlan operations, and is appropriate for Pipeline Operations."
            }
            elseif ($rbacTest.Reader -eq "Passed") {
                $testData.evaluation = "Passed"
                $testData.customReturn = "PassedEpacPlan"
                $testData.message = "This security principal should only be used for Build-DeploymentPlans, and is appropriate for Pipeline Operations."
            }
            else {
                $testData.evaluation = "Failed"
                $testData.customReturn = "FailedAll"
                $testData.message = "This security principal has insufficient rights to continue. Confirm a valid authenticated connection to Azure, confirm the tenant in use, and confirm RBAC rights for the account in use."
                
            }
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType testResult -EntryData "$($testData.name)`: $($testData.customReturn) -- $($testData.message)" -UseUtc:$UseUtc -Silent
            if (!($Silent)) {
                switch ($testData.evaluation) {
                    "Passed" {
                        Write-Host "$ClientId`: $($testData.message)" -ForegroundColor Green
                    }   
                
                    "Failed" {
                        Write-Host "$ClientId`: $($testData.message)" -ForegroundColor Red
                    }
                    default {
                        Write-Error "Unrecognized response, please report bug in RBAC test of `$testData.Evaluation to EPAC team, value returned was $($testData.Evaluation). Please retain the log file to assist with troubleshooting."
                    }
                }
            }
        }

    }
    # Anything with a custom return type will have it's own emits and log entries due to additional complexity. The final cmdlet return is the only shared aspect.
    if ($testData.customReturn) {
        $testData.result = $testData.customReturn
    }
    else {
        # Create standard result from standard $true/$false input
        if ($testData.evaluation) {
            $testData.result = "Passed"
            if (!($Silent)) {
                Write-Host "$($testData.message)" -ForegroundColor Green
            }
        }
        else {
            $testData.result = "Failed"
            # Write an error if that is desired
            if (!($Silent)) {
                Write-Error "$($testData.Message)"
            }

            # If an error message was generated during the test, it will be returned here.
            if ($errorMessage) {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "Error: $errorMessage" -UseUtc:$UseUtc -Silent
                if ($debug) {
                    Write-Error "Command Error Returned:`n    $ErrorMessage"
                }
            }    
        }
    
        # If debugging was specified, output raw returns from the test to the log file, these can be copied and pasted to be imported from json. for review as needed.
        if ($debug) {
            if ($testData.evaluation -is [string] -and !($testData.evaluation -eq [array])) {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "testResult" -EntryData "$($testData.name)` -- EvaluationReturn: $($testData.evaluation)" -UseUtc:$UseUtc
            }
            else {
                Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "testResult" -EntryData "$($testData.name)` -- EvaluationReturn: $($testData.evaluation | Convertto-Json -Depth 100 -Compress)" -UseUtc:$UseUtc -Silent
            }
        }
        else {
            Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "testResult" -EntryData "$($testData.name)` -- EvaluationReturn: $($testData.evaluation)" -UseUtc:$UseUtc -Silent
        }
    }
    Write-HydrationLogFile -LogFilePath $LogFilePath -EntryType "logEntryDataAsPresented" -EntryData "$($testData.name)`: $($testData.result) $($testData.message)" -UseUtc:$UseUtc -Silent
    return $testData.result
}
