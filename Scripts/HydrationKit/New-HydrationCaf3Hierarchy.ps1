<#
.SYNOPSIS
    This function creates a new hierarchy of management groups based on the CAF 3.0 model.

.DESCRIPTION
    The New-HydrationCaf3Hierarchy function takes a prefix and a suffix, and creates a new hierarchy of management groups based on the CAF 3.0 model.

.PARAMETER Prefix
    The prefix to be used in the naming of the new hierarchy. This is not generally recommended as it adds complexity with little RoI, but is an available option.

.PARAMETER Suffix
    The suffix to be used in the naming of the new hierarchy. This is not generally recommended as it adds complexity with little RoI, but is an available option.

.EXAMPLE
    New-HydrationCaf3Hierarchy -Prefix "epacdev-" -Suffix "-dev"

    This will create a new hierarchy of management groups based on the CAF 3.0 model, using "epacdev-" as the prefix and "-dev" as the suffix.   

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
    
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $DestinationRootName,
    [Parameter(Mandatory = $false)]
    [string]
    $Prefix,
    [Parameter(Mandatory = $false)]
    [string]
    $Suffix
)
$InformationPreference = "Continue"
$IRMGChildList = @("Platform", "LandingZones", "Decomissioned", "Sandbox")
$PlatformMGList = @("Identity", "Management", "Connectivity")
$LandingZoneMGList = @("Corp", "Online")
$tRootGroupId = $( -join ("/providers/Microsoft.Management/managementGroups/", $DestinationRootName))
foreach ($t in $IRMGChildList) {
    $rootGroupId = $tRootGroupId
    $i = 0
    $name = $( -join ($Prefix, $t, $Suffix))
    $alreadyExists = Get-AzManagementGroup -GroupName $name -ErrorAction SilentlyContinue
    if ($alreadyExists) {
        Write-Information "Management Group $name already exists in $($alreadyExists.ParentName)."
        continue
    }
    do {
        if ($repeat) {
            $complete = Get-AzManagementGroup -GroupName $name -ErrorAction SilentlyContinue
        }
        $newMg = New-AzManagementGroup -GroupName $name -DisplayName $name -ParentId $rootGroupId
        if (!($newMg)) {
            $repeat = $true
            $i++
        }
    }until($newMg -or $complete -or $i -eq 3)
    if ($i -eq 3) {
        Write-Error "Failed to create $name Management Group"
        return
    }
    Write-Information "Created $name Management Group in $rootGroupId"
}
$pRootGroupId = $( -join ("/providers/Microsoft.Management/managementGroups/", $Prefix, "Platform", $Suffix))
foreach ($p in $PlatformMGList) {
    $rootGroupId = $pRootGroupId
    $i = 0
    $name = $( -join ($Prefix, $p, $Suffix))
    $alreadyExists = Get-AzManagementGroup -GroupName $name -ErrorAction SilentlyContinue
    if ($alreadyExists) {
        Write-Information "Management Group $name already exists in $($alreadyExists.ParentName)."
        continue
    }
    do {
        if ($repeat) {
            $complete = Get-AzManagementGroup -GroupName $name -ErrorAction SilentlyContinue
        }
        $newMg = New-AzManagementGroup -GroupName $name -DisplayName $name -ParentId $rootGroupId
        if (!($newMg)) {
            $repeat = $true
            $i++
        }
    }until($newMg -or $complete -or $i -eq 3)
    if ($i -eq 3) {
        Write-Error "Failed to create $name Management Group in $rootGroupId"
        return
    }
    Write-Information "Created $name Management Group"
}
$lRootGroupId = $( -join ("/providers/Microsoft.Management/managementGroups/", $Prefix, "LandingZones", $Suffix))
foreach ($l in $LandingZoneMGList) {
    $rootGroupId = $lRootGroupId
    $i = 0
    $name = $( -join ($Prefix, $l, $Suffix))
    $alreadyExists = Get-AzManagementGroup -GroupName $name -ErrorAction SilentlyContinue
    if ($alreadyExists) {
        Write-Information "Management Group $name already exists in $($alreadyExists.ParentName)."
        continue
    }
    do {
        if ($repeat) {
            $complete = Get-AzManagementGroup -GroupName $name -ErrorAction SilentlyContinue
        }
        $newMg = New-AzManagementGroup -GroupName $name -DisplayName $name -ParentId $rootGroupId
        if (!($newMg)) {
            $repeat = $true
            $i++
        }
    }until($newMg -or $complete -or $i -eq 3)
    if ($i -eq 3) {
        Write-Error "Failed to create $name Management Group"
        return
    }
    Write-Information "Created $name Management Group in $rootGroupId"
}
