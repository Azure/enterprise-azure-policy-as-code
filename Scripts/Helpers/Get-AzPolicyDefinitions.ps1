#Requires -PSEdition Core

function Get-AzPolicyDefinitions {
    [CmdletBinding()]
    param (
        [hashtable] $pacEnvironment
    )

    $deploymentRootScope = $pacEnvironment.deploymentRootScope
    $policyDefinitionsScopes = $pacEnvironment.policyDefinitionsScopes
    Write-Information "==================================================================================================="
    Write-Information "Fetching existing Policy and Policy Set definitions from scope $($deploymentRootScope)"
    Write-Information "==================================================================================================="

    $policyDefinitionsDeployed = @{
        policy    = @{
            raw      = @{}
            all      = @{}
            builtIn  = @{}
            readOnly = @{}
            managed  = @{}
        }
        policySet = @{
            raw      = @{}
            all      = @{}
            builtIn  = @{}
            readOnly = @{}
            managed  = @{}
        }
    }

    $length = $policyDefinitionsScopes.Length
    $last = $length - 1
    foreach ($definition in @("policy", "policySet")) {
        $policyDefinitions = $policyDefinitionsDeployed.$definition
        $policyList = @()
        $numberCustomReadOnlyPolicies = 0

        if ($definition -eq "policy") {
            $policyList = Invoke-AzCli policy definition list -PolicyDefinitionsScopeId $deploymentRootScope
        }
        else {
            $policyList = Invoke-AzCli policy set-definition list -PolicyDefinitionsScopeId $deploymentRootScope
        }

        foreach ($policy in $policyList) {
            $null = ($policyDefinitions.raw).Add($policy.id, $policy)
            $found = $false
            for ($i = 0; $i -lt $length -and !$found; $i++) {
                $currentPolicyDefinitionsScopeId = $policyDefinitionsScopes[$i]
                if ($policy.id -like "$currentPolicyDefinitionsScopeId*") {
                    switch ($i) {
                        0 {
                            # deploymentRootScope
                            $null = ($policyDefinitions.all).Add($policy.id, $policy)
                            $null = ($policyDefinitions.managed).Add($policy.id, $policy)
                            $found = $true
                        }
                        $last {
                            # BuiltIn or Static, since last entry in array is empty string ($currentPolicyDefinitionsScopeId)
                            $null = ($policyDefinitions.all).Add($policy.id, $policy)
                            $null = ($policyDefinitions.builtIn).Add($policy.id, $policy)
                            $null = ($policyDefinitions.readOnly).Add($policy.id, $policy)
                            $found = $true
                        }
                        Default {
                            # readOnlypolicyDefinitionsScopes
                            $null = ($policyDefinitions.all).Add($policy.id, $policy)
                            $null = ($policyDefinitions.readOnly).Add($policy.id, $policy)
                            $numberCustomReadOnlyPolicies++
                            $found = $true
                        }
                    }
                }
            }
        }

        Write-Information "$definition definitions:"
        Write-Information "    BuiltIn  = $($policyDefinitions.builtIn.Count)"
        Write-Information "    Custom   = $($policyDefinitions.managed.Count)"
        Write-Information "    ReadOnly = $($numberCustomReadOnlyPolicies)"
        # $rawCount = $policyDefinitions.raw.Count
        # $allCount = $policyDefinitions.all.Count
        # Write-Information "    All      = $($allCount)"
        # Write-Information "    Ignored  = $($rawCount - $allCount )"
    }

    Write-Information ""
    Write-Information ""

    return $policyDefinitionsDeployed
}
