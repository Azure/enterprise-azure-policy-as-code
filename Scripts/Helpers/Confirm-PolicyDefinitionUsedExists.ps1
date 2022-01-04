
#Requires -PSEdition Core

function Confirm-PolicyDefinitionUsedExists {
    [CmdletBinding()]
    param(
        [hashtable] $allPolicyDefinitions,
        [hashtable] $replacedPolicyDefinitions,
        [string] $policyNameRequired
    )

    ######## validating Policy Definition existence ###########
    $usingUndefinedReference = $false
    $usingReplacedReference = $false
    $policy = $null


    if ($allPolicyDefinitions.ContainsKey($policyNameRequired)) {
        $policy = $allPolicyDefinitions.$policyNameRequired
        if ($replacedPolicyDefinitions.ContainsKey($policyNameRequired)) {
            $usingReplacedReference = $true
            Write-Verbose "            Referenced Policy ""$($policyDefinition.policyDefinitionName)"" is being replaced with an incompatible newer vcersion"
        }
        else {
            Write-Verbose  "            Referenced Policy ""$($policyDefinition.policyDefinitionName)"" exist"
        }
    }
    else {
        Write-Error "Referenced Policy ""$($policyNameRequired)"" doesn't exist at the specified scope"
        $usingUndefinedReference = $true
    }

    $retValue = @{
        usingUndefinedReference = $usingUndefinedReference
        usingReplacedReference  = $usingReplacedReference
        policy                  = $policy
    }
    $retValue
}
