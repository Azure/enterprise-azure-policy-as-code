<#

.SYNOPSIS
    Get-AzureADUsersLastSignIn PowerShell script.

.DESCRIPTION
    Get-AzureADUsersLastSignIn.ps1 is a PowerShell script retrieves Azure AD users with their last sign in date.

.AUTHOR:
    Mohammad Zmaili

.EXAMPLE
    .\Get-AADUserLastSignIn.ps1
      Retrieves all Azure AD users with their last sign in date.

Important Notes:
    > Tenant should have an Azure Active Directory Premium.
    
    > If 'Last Success Signin (UTC)' value is 'N/A', this could be due to one of the following two reasons:
        - The last successful sign-in of a user took place before April 2020.
        - The affected user account was never used for a successful sign-in.
        
#>

function Connect-AzureDevicelogin {
    [cmdletbinding()]
    param( 
        [Parameter()]
        $ClientID,
        
        [Parameter()]
        [switch]$Interactive,
        
        [Parameter()]
        $TenantID = 'common',
        
        [Parameter()]
        $Resource = "https://graph.microsoft.com/",
        
        # Timeout in seconds to wait for user to complete sign in process
        [Parameter(DontShow)]
        $Timeout = 300
    )
try {
    $DeviceCodeRequestParams = @{
        Method = 'POST'
        Uri    = "https://login.microsoftonline.com/$TenantID/oauth2/devicecode"
        Body   = @{
            resource  = $Resource
            client_id = $ClientId
            redirect_uri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
            #scope = "Directory.Read.All,AuditLog.Read.All"
            scope = "AuditLog.Read.All"
        }
    }
    $DeviceCodeRequest = Invoke-RestMethod @DeviceCodeRequestParams
 
    # Copy device code to clipboard
    $DeviceCode = ($DeviceCodeRequest.message -split "code " | Select-Object -Last 1) -split " to authenticate."
    Set-Clipboard -Value $DeviceCode

    Write-Host "Device code " -ForegroundColor Yellow -NoNewline
    Write-Host $DeviceCode -ForegroundColor Green -NoNewline
    Write-Host "has been copied to the clipboard, please paste it into the opened 'Microsoft Graph Authentication' window, complete the signin, and close the window to proceed." -ForegroundColor Yellow
    Write-Host "Note: If 'Microsoft Graph Authentication' window didn't open,"($DeviceCodeRequest.message -split "To sign in, " | Select-Object -Last 1) -ForegroundColor gray

    # Open Authentication form window
    Add-Type -AssemblyName System.Windows.Forms
    $form = New-Object -TypeName System.Windows.Forms.Form -Property @{ Width = 440; Height = 640 }
    $web = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{ Width = 440; Height = 600; Url = "https://www.microsoft.com/devicelogin" }
    $web.Add_DocumentCompleted($DocComp)
    $web.DocumentText
    $form.Controls.Add($web)
    $form.Add_Shown({ $form.Activate() })
    $web.ScriptErrorsSuppressed = $true
    $form.AutoScaleMode = 'Dpi'
    $form.text = "Microsoft Graph Authentication"
    $form.ShowIcon = $False
    $form.AutoSizeMode = 'GrowAndShrink'
    $Form.StartPosition = 'CenterScreen'
    $form.ShowDialog() | Out-Null
        
    $TokenRequestParams = @{
        Method = 'POST'
        Uri    = "https://login.microsoftonline.com/$TenantId/oauth2/token"
        Body   = @{
            grant_type = "urn:ietf:params:oauth:grant-type:device_code"
            code       = $DeviceCodeRequest.device_code
            client_id  = $ClientId
        }
    }
    $TimeoutTimer = [System.Diagnostics.Stopwatch]::StartNew()
    while ([string]::IsNullOrEmpty($TokenRequest.access_token)) {
        if ($TimeoutTimer.Elapsed.TotalSeconds -gt $Timeout) {
            throw 'Login timed out, please try again.'
        }
        $TokenRequest = try {
            Invoke-RestMethod @TokenRequestParams -ErrorAction Stop
        }
        catch {
            $Message = $_.ErrorDetails.Message | ConvertFrom-Json
            if ($Message.error -ne "authorization_pending") {
                throw
            }
        }
        Start-Sleep -Seconds 1
    }
    Write-Output $TokenRequest.access_token
}
finally {
    try {
        Remove-Item -Path $TempPage.FullName -Force -ErrorAction Stop
        $TimeoutTimer.Stop()
    }
    catch {
        # We don't care about errors here
    }
}
}

''
'========================================================'
Write-Host '            Azure AD Users Last SignIn Report          ' -ForegroundColor Green 
'========================================================'
''

$accesstoken = Connect-AzureDevicelogin

$AADUsers = @()
$headers = @{ 
            'Content-Type'  = "application\json"
            'Authorization' = "Bearer $accesstoken"
            }

$GraphLink = "https://graph.microsoft.com/beta/users?$"
$GraphLink = $GraphLink + "select=userPrincipalName,displayName,userType,accountEnabled,createdDateTime,signInActivity"

do{
    try{
        $ADUseresult = Invoke-WebRequest -Headers $Headers -Uri $GraphLink -UseBasicParsing -Method "GET" -ContentType "application/json"
    }catch{
        Write-Host ''
        Write-Host ''
        Write-Host "Operation aborted. Please make sure that tenant has an Azure Active Directory Premium license, and you have the right permissions." -ForegroundColor red -BackgroundColor Black
        Write-Host ''
        Write-Host "Script completed successfully." -ForegroundColor Green -BackgroundColor Black
        Write-Host ''
        exit
    }
    $ADUseresult = $ADUseresult.Content | ConvertFrom-Json
        if ($ADUseresult.value) {
            $AADUsers += $ADUseresult.value
        }
        else {
            $AADUsers += $ADUseresult
        }
        $GraphLink = ($ADUseresult).'@odata.nextlink'
  } until (!($GraphLink)) 

$ADUserep =@()
foreach($ADUser in $AADUsers){
    $ADUserepobj = New-Object PSObject
    $ADUserepobj | Add-Member NoteProperty -Name "Display Name" -Value $ADUser.displayName
    $ADUserepobj | Add-Member NoteProperty -Name "User Principal Name" -Value $ADUser.userPrincipalName
    $ADUserepobj | Add-Member NoteProperty -Name "User Type" -Value $ADUser.userType
    if ($ADUser.accountEnabled){$ADUserepobj | Add-Member NoteProperty -Name "Account Enabled" -Value $ADUser.accountEnabled}else{$ADUserepobj | Add-Member NoteProperty -Name "Account Enabled" -Value "False"}
    $ADUserepobj | Add-Member NoteProperty -Name "Created DateTime (UTC)" -Value $ADUser.createdDateTime
    if (($ADUser.signInActivity).lastSignInDateTime) {$ADUserepobj | Add-Member NoteProperty -Name "Last Success Signin (UTC)" -Value ($ADUser.signInActivity).lastSignInDateTime}else{$ADUserepobj | Add-Member NoteProperty -Name "Last Success Signin (UTC)" -Value "N/A"}
    $ADUserep += $ADUserepobj
}

$Date=("{0:s}" -f (get-date)).Split("T")[0] -replace "-", ""
$Time=("{0:s}" -f (get-date)).Split("T")[1] -replace ":", ""
$filerep = "AzureADUsersLastLogin_" + $Date + $Time + ".csv"
try{
    $ADUserep | Export-Csv -path $filerep -NoTypeInformation
}catch{
    Write-Host ''
    Write-Host ''
    Write-Host "Operation aborted. Please make sure you have write permission on to write CSV file." -ForegroundColor red -BackgroundColor Black
    Write-Host ''
    Write-Host "Script completed successfully." -ForegroundColor Green -BackgroundColor Black
    Write-Host ''
    exit
}

''
Write-Host "==================================="
Write-Host "|Retreived Azure AD Users Summary:|"
Write-Host "==================================="
Write-Host "Number of retreived AAD Users:" $ADUserep.Count
''
$loc=Get-Location
Write-host $filerep "report has been created under the path:" $loc -ForegroundColor green

''
''
Write-Host "Script completed successfully." -ForegroundColor Green -BackgroundColor Black
''