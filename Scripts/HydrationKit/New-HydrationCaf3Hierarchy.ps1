
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
function New-HydrationCaf3Hierarchy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The name of the destination root management group. This parameter is mandatory.")]
        [string]
        $DestinationRootName,
        [Parameter(Mandatory = $false, HelpMessage = "The prefix to be used in the naming of the new hierarchy. This is not generally recommended as it adds complexity with little RoI, but is an available option.")]
        [string]
        $Prefix,
        [Parameter(Mandatory = $false, HelpMessage = "The suffix to be used in the naming of the new hierarchy. This is not generally recommended as it adds complexity with little RoI, but is an available option.")]
        [string]
        $Suffix
    )
    $InformationPreference = "Continue"
    $mgLists = [ordered]@{
        $DestinationRootName = @("Platform", "LandingZones", "Decommissioned", "Sandbox")
        Platform             = @("Identity", "Management", "Connectivity")
        LandingZones         = @("Corp", "Online")
    }
    foreach ($listName in $mgLists.Keys) {
        if ($DestinationRootName -eq $listName) {
            $parentName = $listName
        }
        else {
            $parentName = $( -join ($Prefix, $listName, $Suffix))
        }
        $rootGroupId = $( -join ("/providers/Microsoft.Management/managementGroups/", $parentName))
        foreach ($t in $mgLists.($listName)) {
            $i = 0
            $name = $( -join ($Prefix, $t, $Suffix))
            Remove-Variable repeat -ErrorAction SilentlyContinue
            do {
                $null = Remove-variable testResult -ErrorAction SilentlyContinue
                $null = Remove-variable complete -ErrorAction SilentlyContinue
                try {
                    $null = $testResult = Get-AzManagementGroupRestMethod -GroupId $name -ErrorAction SilentlyContinue
                }
                catch {
                    $complete = $false
                }
                if ($testResult.name) {
                    # This exists for several reasons: 
                    #    First, timeout errors on response to new-azmanagementgroup are addressed this way.
                    #    Second, this avoids collisions, and notifies of the location if one occurs.
                    #    Third, this accelerates a retry if the first attempt is interrupted.
                    $complete = $true
                    Write-Information "Management Group $name confirmed in $($testResult.properties.details.parent.name)."
                }
                if (!($complete -eq $true)) {
                    try {
                        $null = $newMg = New-AzManagementGroup -GroupName $name -DisplayName $name -ParentId $rootGroupId -ErrorAction SilentlyContinue
                    }
                    catch {
                        $null = $newMg = Get-AzManagementGroupRestMethod -GroupId $name -ErrorAction SilentlyContinue
                        Write-Error $_.Exception.Message
                    }
                }
                if (!($newMg)) {
                    if ($i -gt 0) {
                        Write-Warning "Failed to Create Management Group $name, this is generally caused by a timeout on the API call, and will automatically retry $(10-$i) more times..."
                    }                    
                    $i++
                }
            }until($newMg -or $complete -or $i -eq 10)
            if ($i -eq 3) {
                Write-Error "Failed to create $name Management Group"
                return
            }
            Write-Information "Verified $name Management Group in $rootGroupId"
        }
    }
}