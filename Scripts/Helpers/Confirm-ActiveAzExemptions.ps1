function Confirm-ActiveAzExemptions {
    [CmdletBinding()]
    param (
        $Exemptions,
        $Assignments
    )

    # Process Exemptions
    [hashtable] $allExemptions = @{}
    [hashtable] $activeExemptions = @{}
    [hashtable] $expiringExemptions = @{}
    [hashtable] $expiredExemptions = @{}
    [hashtable] $orphanedExemptions = @{}

    $now = Get-Date
    foreach ($exemptionId in $Exemptions.Keys) {
        $exemption = $Exemptions.$exemptionId
        $PolicyAssignmentId = $exemption.policyAssignmentId
        $isValid = $Assignments.ContainsKey($PolicyAssignmentId)
        $expiresOnString = $exemption.expiresOn
        $expired = $false
        $expiresInDays = [Int32]::MaxValue
        if ($exemption.expiresOn) {
            $expiresOn = [datetime]::Parse($expiresOnString)
            $expired = $expiresOn -lt $now
            $expiresIn = New-TimeSpan -Start $now -End $expiresOn
            $expiresInDays = $expiresIn.Days
        }
        $status = "orphaned"
        if ($isValid) {
            if ($expired) {
                $status = "expired"
            }
            else {
                $status = "active"
            }
        }

        $Name = $exemption.name
        $DisplayName = $exemption.displayName
        if ($null -eq $DisplayName) {
            $DisplayName = $Name
        }

        $Metadata = $exemption.metadata
        if ($Metadata -eq @{}) {
            $Metadata = $null
        }

        $ExemptionObj = [pscustomobject][ordered]@{
            name                         = $Name
            displayName                  = $exemption.displayName
            description                  = $exemption.description
            exemptionCategory            = $exemption.exemptionCategory
            expiresOn                    = $expiresOnString
            status                       = $status
            expiresInDays                = $expiresInDays
            scope                        = $exemption.scope
            policyAssignmentId           = $PolicyAssignmentId
            policyDefinitionReferenceIds = $exemption.policyDefinitionReferenceIds
            metadata                     = $Metadata
            id                           = $exemptionId
        }

        $null = $allExemptions.Add($exemptionId, $ExemptionObj)
        switch ($status) {
            active {
                $null = $activeExemptions.Add($exemptionId, $ExemptionObj)
            }
            orphaned {
                $null = $orphanedExemptions.Add($exemptionId, $ExemptionObj)
            }
            expired {
                $null = $expiredExemptions.Add($exemptionId, $ExemptionObj)
            }
        }
    }

    $ExemptionsResult = @{
        all           = $allExemptions
        active        = $activeExemptions
        expiresInDays = $expiringExemptions # Subset of active
        orphaned      = $orphanedExemptions # Orpahned trumps expired
        expired       = $expiredExemptions
    }

    return $ExemptionsResult
}
