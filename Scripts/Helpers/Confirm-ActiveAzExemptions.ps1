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
        $policyAssignmentId = $exemption.policyAssignmentId
        $isValid = $Assignments.ContainsKey($policyAssignmentId)
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

        $name = $exemption.name
        $displayName = $exemption.displayName
        if ($null -eq $displayName) {
            $displayName = $name
        }

        $metadata = $exemption.metadata
        if ($metadata -eq @{}) {
            $metadata = $null
        }

        $exemptionObj = [pscustomobject][ordered]@{
            name                         = $name
            displayName                  = $exemption.displayName
            description                  = $exemption.description
            exemptionCategory            = $exemption.exemptionCategory
            expiresOn                    = $expiresOnString
            status                       = $status
            expiresInDays                = $expiresInDays
            scope                        = $exemption.scope
            policyAssignmentId           = $policyAssignmentId
            policyDefinitionReferenceIds = $exemption.policyDefinitionReferenceIds
            metadata                     = $metadata
            id                           = $exemptionId
        }

        $null = $allExemptions.Add($exemptionId, $exemptionObj)
        switch ($status) {
            active {
                $null = $activeExemptions.Add($exemptionId, $exemptionObj)
            }
            orphaned {
                $null = $orphanedExemptions.Add($exemptionId, $exemptionObj)
            }
            expired {
                $null = $expiredExemptions.Add($exemptionId, $exemptionObj)
            }
        }
    }

    $exemptionsResult = @{
        all           = $allExemptions
        active        = $activeExemptions
        expiresInDays = $expiringExemptions # Subset of active
        orphaned      = $orphanedExemptions # Orpahned trumps expired
        expired       = $expiredExemptions
    }

    return $exemptionsResult
}
