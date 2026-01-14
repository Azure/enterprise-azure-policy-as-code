<#
.SYNOPSIS
    Cleans up all EPAC regression test resources from Azure.
.DESCRIPTION
    Removes all policy resources created during regression testing
    that match the test prefix pattern.
.EXAMPLE
    .\Cleanup-TestEnvironment.ps1 -ManagementGroupId "epac-test-mg"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManagementGroupId,
    
    [Parameter(Mandatory = $false)]
    [string]$TestPrefix = "test-",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Dot source modern output functions
. "$PSScriptRoot/../../Scripts/Helpers/Write-ModernOutput.ps1"

Write-ModernHeader -Title "Cleaning Up EPAC Test Resources"

if ($WhatIf) {
    Write-ModernStatus -Message "Running in WhatIf mode - no changes will be made" -Status "info"
}

$mgScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

# Step 1: Remove Policy Exemptions
Write-ModernSection -Title "[1/4] Removing policy exemptions"
try {
    $exemptions = Get-AzPolicyExemption -Scope $mgScope -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "$TestPrefix*" }
    
    foreach ($exemption in $exemptions) {
        if ($WhatIf) {
            Write-ModernStatus -Message "Would remove exemption: $($exemption.Name)" -Status "info" -Indent 2
        } else {
            Write-ModernStatus -Message "Removing: $($exemption.Name)" -Status "processing" -Indent 2
            Remove-AzPolicyExemption -Name $exemption.Name -Scope $mgScope -Force -Confirm:$false
        }
    }
    Write-ModernStatus -Message "Removed $(@($exemptions).Count) exemptions" -Status "success" -Indent 2
} catch {
    Write-ModernStatus -Message "Error removing exemptions: $_" -Status "warning" -Indent 2
}

# Step 2: Remove Policy Assignments
Write-ModernSection -Title "[2/4] Removing policy assignments"
try {
    $assignments = Get-AzPolicyAssignment -Scope $mgScope -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "$TestPrefix*" }
    
    foreach ($assignment in $assignments) {
        if ($WhatIf) {
            Write-ModernStatus -Message "Would remove assignment: $($assignment.Name)" -Status "info" -Indent 2
        } else {
            Write-ModernStatus -Message "Removing: $($assignment.Name)" -Status "processing" -Indent 2
            Remove-AzPolicyAssignment -Name $assignment.Name -Scope $mgScope -Confirm:$false
        }
    }
    Write-ModernStatus -Message "Removed $(@($assignments).Count) assignments" -Status "success" -Indent 2
} catch {
    Write-ModernStatus -Message "Error removing assignments: $_" -Status "warning" -Indent 2
}

# Step 3: Remove Policy Set Definitions
Write-ModernSection -Title "[3/4] Removing policy set definitions"
try {
    $policySets = Get-AzPolicySetDefinition -ManagementGroupName $ManagementGroupId -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "$TestPrefix*" }
    
    foreach ($policySet in $policySets) {
        if ($WhatIf) {
            Write-ModernStatus -Message "Would remove policy set: $($policySet.Name)" -Status "info" -Indent 2
        } else {
            Write-ModernStatus -Message "Removing: $($policySet.Name)" -Status "processing" -Indent 2
            Remove-AzPolicySetDefinition -Name $policySet.Name -ManagementGroupName $ManagementGroupId -Force -Confirm:$false
        }
    }
    Write-ModernStatus -Message "Removed $(@($policySets).Count) policy sets" -Status "success" -Indent 2
} catch {
    Write-ModernStatus -Message "Error removing policy sets: $_" -Status "warning" -Indent 2
}

# Step 4: Remove Policy Definitions
Write-ModernSection -Title "[4/4] Removing policy definitions"
try {
    $policies = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupId -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -like "$TestPrefix*" }
    
    foreach ($policy in $policies) {
        if ($WhatIf) {
            Write-ModernStatus -Message "Would remove policy: $($policy.Name)" -Status "info" -Indent 2
        } else {
            Write-ModernStatus -Message "Removing: $($policy.Name)" -Status "processing" -Indent 2
            Remove-AzPolicyDefinition -Name $policy.Name -ManagementGroupName $ManagementGroupId -Force -Confirm:$false
        }
    }
    Write-ModernStatus -Message "Removed $(@($policies).Count) policy definitions" -Status "success" -Indent 2
} catch {
    Write-ModernStatus -Message "Error removing policies: $_" -Status "warning" -Indent 2
}

Write-Host ""
Write-ModernStatus -Message "Cleanup complete" -Status "success"

return @{
    ExemptionsRemoved = @($exemptions).Count
    AssignmentsRemoved = @($assignments).Count
    PolicySetsRemoved = @($policySets).Count
    PoliciesRemoved = @($policies).Count
}
