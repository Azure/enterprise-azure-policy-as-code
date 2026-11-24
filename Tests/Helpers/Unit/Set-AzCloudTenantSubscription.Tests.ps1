BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Set-AzCloudTenantSubscription.ps1')

    # Stubs, so the tests do not need Az.Accounts
    function Get-AzSubscription {}
    function Get-AzContext {}
    function Set-AzContext { param([Parameter(ValueFromPipeline)] $SubscriptionObject, [string] $Subscription) process {} }
    function Update-AzConfig { param($DisplayBreakingChangeWarning) }

    $tenantId = '00000000-0000-0000-0000-000000000001'
}

Describe 'Set-AzCloudTenantSubscription' {
    BeforeEach {
        # Like PSAzureTenant: compared as a string, it is the tenant ID
        $tenant = [pscustomobject]@{ Id = $tenantId; TenantId = $tenantId }
        $tenant | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Id } -Force
        Mock Get-AzContext { [pscustomobject]@{ Environment = @{ Name = 'AzureCloud' }; Tenant = $tenant } }
        Mock Set-AzContext {}
        Mock Update-AzConfig {}
    }

    It 'skips a subscription in state <_> and sets only the first enabled subscription' -ForEach 'Disabled', 'Warned', 'PastDue' {
        $state = $_
        Mock Get-AzSubscription {
            [pscustomobject]@{ Name = 'not-enabled'; State = $state; HomeTenantId = $tenantId }
            [pscustomobject]@{ Name = 'enabled'; State = 'Enabled'; HomeTenantId = $tenantId }
            [pscustomobject]@{ Name = 'enabled-2'; State = 'Enabled'; HomeTenantId = $tenantId }
        }

        $null = Set-AzCloudTenantSubscription -Cloud 'AzureCloud' -TenantId $tenantId -Interactive $false

        Should -Invoke Set-AzContext -Times 1 -Exactly
        Should -Invoke Set-AzContext -Times 1 -Exactly -ParameterFilter { $SubscriptionObject.Name -eq 'enabled' }
    }
}
