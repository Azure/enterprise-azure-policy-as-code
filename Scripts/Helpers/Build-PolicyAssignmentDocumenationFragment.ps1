#Requires -PSEdition Core

function Get-SortOrdinal {
    param (
        [string] $effect
    )

    $effect2sortOrdinal = @{
        Modify            = 0
        Append            = 1
        DeployIfNotExists = 2
        Deny              = 3
        AuditIfNotExists  = 4
        Audit             = 4
        Disabled          = 5
    }


    $ordinal = -1 # should not be possible
    if ($effect2sortOrdinal.ContainsKey($effect)) {
        $ordinal = $effect2sortOrdinal.$effect
    }
    return $ordinal
}

function Get-Effect {
    param (
        [string] $ordinal
    )

    $sortOrdinal2effect = @(
        "Modify Poices",
        "Append Policies",
        "DeployIfNotExists Policies",
        "Deny Policies",
        "Audit Policies",
        "Disabled Policies"
    )

    $effect = "Unknown"
    if ($ordinal -ge 0 -and $ordinal -lt $sortOrdinal2effect.Count) {
        $effect = $sortOrdinal2effect[$ordinal]
    }
    return $effect
}

function Build-PolicyAssignmentDocumenationFragment {
    [CmdletBinding()]
    param (
        [int] $headingLevel,
        [array] $assignmentArray,
        [hashtable] $policyInitiativeInfo,
        [hashtable] $assignmentsInfo
    )

    [System.Collections.Generic.List[string]] $linesAdded = [System.Collections.Generic.List[string]]::new()

    #region Emit List of Assignments

    $null = $linesAdded.Add("`n$('#'*$headingLevel) Assignments`n")
    $atLeastOneInitiative = $false
    foreach ($assignmentEntry in $assignmentArray) {
        $assignmentId = $assignmentEntry.id
        $shortName = $assignmentEntry.shortName
        if ($assignmentsInfo.ContainsKey($assignmentId)) {
            $assignmentInfo = $assignmentsInfo.$assignmentId
            if ($assignmentInfo.isInitiative) {
                $null = $linesAdded.Add("- Initiative: $($assignmentInfo.initiativeDisplayName) ($shortName)")
                $null = $linesAdded.Add("  - $($assignmentInfo.initiativeDescription)")
                $null = $linesAdded.Add("  - Type: $($assignmentInfo.initiativePolicyType)")
                $null = $linesAdded.Add("  - Category: $($assignmentInfo.initiativeCategory)")
                $atLeastOneInitiative = $true
            }
            else {
                $policyDefinitionsInfo = $assignmentInfo.policyDefinitionsInfo[0]
                $parameters = $policyDefinitionInfo.parameters
                $null = $linesAdded.Add("- Policy: $($policyDefinitionsInfo.displayName) ($shortName)")
                $null = $linesAdded.Add("  - $($policyDefinitionsInfo.decription)")
                $null = $linesAdded.Add("  - Type: $($policyDefinitionsInfo.policyType)")
                $null = $linesAdded.Add("  - Category: $($policyDefinitionsInfo.category)")
                $null = $linesAdded.Add("  - Effect: $($policyDefinitionsInfo.effectValue)")
            }
            $null = $linesAdded.Add("<br/><br/>")
        }
    }

    #endregion Emit List of Assignments

    if ($atLeastOneInitiative) {

        #region Flatten structure by effect, category, policy display name

        $flatPolicyList = @{}
        foreach ($assignmentEntry in $assignmentArray) {
            $assignmentId = $assignmentEntry.id
            $shortName = $assignmentEntry.shortName
            if ($assignmentsInfo.ContainsKey($assignmentId)) {
                $assignmentInfo = $assignmentsInfo.$assignmentId
                if ($assignmentInfo.isInitiative) {
                    $assignmentId = $assignment.id
                    foreach ($policyDefinitionInfo in $assignmentInfo.policyDefinitionsInfos) {
                        $id = $policyDefinitionInfo.id
                        $effect = $policyDefinitionInfo.effectValue
                        $ordinal = Get-SortOrdinal -ordinaledEffects $ordinaledEffects -effect $effect

                        [hashtable] $currentAssignmentAndFlatPolicyInfo = @{
                            effect              = $effect
                            ordinal             = $ordinal
                            assignmentShortName = $shortName
                            parameters          = $policyDefinitionInfo.parameters
                        }
                        
                        if ($flatPolicyList.ContainsKey($id)) {
                            [hashtable] $flatPolicyInfo = $flatPolicyList.$id
                            [hashtable] $effectiveAssignment = $flatPolicyInfo.effectiveAssignment
                            [hashtable] $allAssignments = $flatPolicyInfo.allAssignments
                            if ($ordinal -lt $effectiveAssignmnet.ordinal) {
                                $flatPolicyInfo.effectiveAssignment = $effectiveAssignment
                            }
                            $allAssignments.Add($shortName, $currentAssignmentAndFlatPolicyInfo)
                        }
                        else {
                            # First time encountering Policy
                            $displayName = $policyDefinitionInfo.name
                            if ($policyDefinitionInfo.displayName) {
                                $displayName = $policyDefinitionInfo.displayName
                            }
                            $description = ""
                            if ($policyDefinitionInfo.description) {
                                $description = $policyDefinitionInfo.description
                            }
                            $effect = $policyDefinitionInfo.effectValue

                            $flatPolicyInfo = @{
                                category            = $policyDefinitionInfo.category
                                displayName         = $displayName
                                description         = $description
                                effectiveAssignment = $currentAssignmentAndFlatPolicyInfo
                                allAssignments      = @{
                                    $shortName = $currentAssignmentAndFlatPolicyInfo
                                }
                            }
                            $flatPolicyList.Add($id, $flatPolicyInfo)
                        }
                    }
                }
            }
        }

        #endegion Flatten structure by effect, category, policy display name

        #egion Emit Policy Tables by Effect

        $previousOrdinal = -1
        $flatPolicyList.Values | Sort-Object -Property { $_.ordinal }, { $_.category }, { $_.displayName } | ForEach-Object -Process {
            $currentOrdinal = $_.ordinal
            if ($previousOrdinal -ne $currentOrdinal) {
                $heading = Get-Effect -ordinal $currentOrdinal
                $null = $linesAdded.Add("<br/>`n$('#'*$headingLevel) $($heading)`n<br/>`n")
                $null = $linesAdded.Add("| Category | Initiative | Policy |")
                $null = $linesAdded.Add("|----------|:----------:|--------|")
                $previousOrdinal = $currentOrdinal
            }

            $parameters = $_.parameters
            $parameterFragments = ""
            if ($parameters.Count -gt 0) {
                $parameterFragments = "<br/>"
                foreach ($parameterName in $parameters.Keys) {
                    $parameter = $parameters.$parameterName
                    $displayName = $parameter.name
                    if ($parameter.displayName) {
                        $displayName = $parameter.displayName
                    }
                    $value = $parameter.value
                    if ($value -is [hashtable] -or $parameter -is [PSCustomObject]) {
                        $value = ConvertTo-Json $value -Compress
                    }
                    $parameterFragments += "<br/>*$displayName=$value*"
                }
            }
            $null = $linesAdded.Add("| $($_.category) | $($_.shortName) | **$($_.displayName)**<br/>$($_.description)$($parameterFragments) |")
        }

        #egion Emit Policy Tables by Effect

    }

    return $linesAdded
}