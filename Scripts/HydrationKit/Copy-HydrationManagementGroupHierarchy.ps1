<#
.SYNOPSIS
    This function copies a management group hierarchy.

.DESCRIPTION
    The Copy-HydrationManagementGroupHierarchy function takes a source group name, a destination parent group name, and a prefix. 
    It then copies the management group hierarchy from the source to the destination.

.PARAMETER SourceGroupName
    The name of the source group from which the hierarchy will be copied.

.PARAMETER DestinationParentGroupName
    The name of the destination parent group where the hierarchy will be copied to.

.PARAMETER Prefix
    The prefix to be used in the naming of the copied hierarchy.

.PARAMETER Suffix
    The suffix to be used in the naming of the copied hierarchy.

.EXAMPLE
    Copy-HydrationManagementGroupHierarchy -SourceGroupName "IntermediateRoot" -DestinationParentGroupName "11111111-1111-1111-1111-111111111111" -Prefix "EpacDev-"

    This will copy the hierarchy from "IntermediateRoot" to the tenant root "11111111-1111-1111-1111-111111111111", using "EpacDev-IntermediateRoot" as the new Intermediate Root for this environment.
    
.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
.NOTES
    While this is most commonly used to generate development environment for EPAC to use in its CI/CD testing, it is a general purpose tool that can be used to rapidly replicate any hierarchy to generate a new parallel hierarchical structure.
#>
function Copy-HydrationManagementGroupHierarchy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The name of the source group from which the hierarchy will be copied.")]
        [string]
        $SourceGroupName,
        [Parameter(Mandatory = $true, HelpMessage = "The name of the destination parent group where the hierarchy will be copied to.")]
        [string]
        $DestinationParentGroupName,
        [Parameter(Mandatory = $false, HelpMessage = "The prefix to be used in the naming of the copied hierarchy.")]
        [string]
        $Prefix,
        [Parameter(Mandatory = $false, HelpMessage = "The suffix to be used in the naming of the copied hierarchy.")]
        [string]
        $Suffix
    )
    $InformationPreference = "Continue"
    if (!($Suffix) -and !($Prefix)) {
        Write-Error "You must modify the name with either a Suffix, a Prefix, or both in order to replicate within the current tenant without naming collision errors."
    }
    try {
        $null = $destParent = Get-AzManagementGroupRestMethod -GroupID $DestinationParentGroupName `
            -ErrorAction SilentlyContinue
    }
    catch {
        Write-Information $_.Exception.Message
        Write-Error "Cannot continue, a valid `$DestinationParentGroupName must be specified to tell the cmdlet where to anchor your new hierarchy."
        return
    }
    Write-Information "Beginning Duplication to $DestinationParentGroupName..."
    $hierarchy = Get-AzManagementGroupRestMethod -GroupID $SourceGroupName -Expand  -Recurse 
    Write-Information "    Creating $(-join($Prefix,$hierarchy.Name,$Suffix))..."
    # Error action included because timeouts happen frequently, but mean nothing. Rather than have responses cause concern, we simply suppress the error.
    $null = New-AzManagementGroup -GroupName $( -join ($Prefix, $hierarchy.Name, $Suffix)) `
        -DisplayName $( -join ($Prefix, $hierarchy.properties.displayName, $Suffix)) `
        -ParentId $destParent.Id -ErrorAction SilentlyContinue
    New-HydrationManagementGroupChildren -Hierarchy $hierarchy `
        -Prefix $Prefix `
        -Suffix $Suffix
}