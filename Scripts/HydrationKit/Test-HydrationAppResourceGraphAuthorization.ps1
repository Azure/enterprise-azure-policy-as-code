param (
    [Parameter(Mandatory = $true)]
    [string]$appId,
    [Parameter(Mandatory = $true)]
    [string]$tenantId
)
$InformationPreference = "Continue"
# List of Microsoft Graph permissions
$permissions = @(
    "Directory.Read.All",
    "Group.Read.All",
    "ServicePrincipalEndpoint.Read.All",
    "User.Read.All"
)
try {
    $graphServicePrincipal = Get-AzADServicePrincipal -DisplayName "Microsoft Graph"
}
catch {
    $e1 = $_.Exception.Message
    write-error $e1
    switch -Wildcard ($e1) {
        "*Please login using Connect-AzAccount*" {
            Write-Error "Please connect to Azure using Connect-AzAccount before using this function."
            exit 1
        }
        default {
            exit 1
        }

    }
}
$graphServiceAppId = $graphServicePrincipal.AppId

# Gather Graph GUID by expressed values above
try {
    $graphResponse = Invoke-RestMethod `
        -Method Get `
        -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$graphServicePrincipalId" `
        -ErrorAction Stop `
        -Headers @{ 
        "Authorization" = "Bearer $((Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token)"
        "Content-Type"  = "application/json"
    }
}
catch {
    $e1 = $_.Exception.Message
    write-error $e1
    switch -Wildcard ($e1) {
        "*Please login using Connect-AzAccount*" {
            Write-Error "Please connect to Azure using Connect-AzAccount before using this function."
            exit 1
        }
        "*The remote server returned an error: (404) Not Found.*" {
            Write-Error "Microsoft Graph Service Principal not found. Confirm the Microsoft Graph Service Principal exists in the tenant."
            exit 1
        }
        default {
            Write-Error "An error occurred while attempting to gather Microsoft Graph Service Principal information, confirm your access to this data."
            exit 1
        }
    }
}

$permissionsObjects = $graphResponse.appRoles | Where-Object { $permissions -contains $_.value }
# Gather assigned permissions on appId
try {
    $permissionsAssigned = Get-AzADAppPermission -ApplicationId $appId -ErrorAction stop | Where-Object { $_.ApiId.Guid -eq $graphServiceAppId }
}
catch {
    $e1 = $_.Exception.Message
    write-error $e1
    switch -Wildcard ($e1) {
        "*Unrecognized Guid format*" {
            Write-Error "This is most commonly caused by attempting to use the AppId field to refer to objects other than Entra ID Registered Applications."
            exit 1
        }
        "*find application by ApplicationId*" {
            Write-Error "This is most commonly caused by attempting to use the ObjectId value in the AppId field to refer toobjects other than Entra ID Registered Applications. Confirm your AppId GUID."
            exit 1
        }
        default {
            exit 1
        }
    }
}
# Test Permissions
foreach ($pm in $permissionsObjects) {
    if (!($permissionsAssigned.Id -contains $pm.id)) {
        Write-Warning "Permission $($pm.value) not found for AppId $appId in Graph API"
        $failed = $True
    }
}
if ($failed) {
    Write-Error "Test Failed, insufficient Graph API permissions found for successful use of EPAC for AppId $appId"
    exit 1
}
else {
    Write-Information "Tests passed, sufficient Graph API permissions found for successful use of EPAC for AppId $appId"
    exit 0
}
