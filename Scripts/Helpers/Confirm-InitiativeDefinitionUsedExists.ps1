#Requires -PSEdition Core

function Confirm-InitiativeDefinitionUsedExists {
    [CmdletBinding()]
    param(
        [hashtable] $allInitiativeDefinitions,
        [hashtable] $replacedInitiativeDefinitions,
        [string] $initiativeNameRequired
    )

    ######## validating initiativeDefinition existence ###########
    $usingUndefinedReference = $false
    $usingReplacedReference = $false
    $initiativeId = $null

    if (-not ($allInitiativeDefinitions.ContainsKey($initiativeNameRequired))) {
        Write-Error "Referenced Initiative ""$($initiativeNameRequired)"" doesn't exist at the specified scope" -ErrorAction Stop
        $usingUndefinedReference = $true
    }
    else {
        if ($replacedInitiativeDefinitions.ContainsKey($initiativeNameRequired)) {
            $usingReplacedReference = $true
            Write-Verbose "        Referenced Initiative ""$($initiativeNameRequired)"" is being replaced with an incompatible newer vcersion"
        }
        else {
            Write-Verbose  "        Referenced Initiative ""$($initiativeNameRequired)"" exist"
        }
    }

    $retValue = @{
        usingUndefinedReference = $usingUndefinedReference
        usingReplacedReference  = $usingReplacedReference
        initiativeId            = $initiativeId
    }
    $retValue
}
