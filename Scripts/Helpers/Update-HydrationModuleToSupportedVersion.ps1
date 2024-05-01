<#
.SYNOPSIS
    This updates the Hydration Module to a supported version.

.DESCRIPTION
    The Update-HydrationModuleToSupportedVersion updates the Hydration Module to a version that is equal to or higher than the LowestSupportedVersion. It takes three parameters: LowestSupportedVersion, ModuleName, and Interactive.

.PARAMETER LowestSupportedVersion
    The lowest version of the module that is supported. This parameter is mandatory.

.PARAMETER ModuleName
    The name of the module to update. Defaults to "EnterprisePolicyAsCode".

.PARAMETER Interactive
    A switch parameter. If provided, the will run in interactive mode.

.EXAMPLE
    Update-HydrationModuleToSupportedVersion -LowestSupportedVersion "1.0.0" -ModuleName "CustomModule" -Interactive

    This example updates the "CustomModule" to a version that is equal to or higher than "1.0.0" in interactive mode.

.NOTES
    The command checks if the module is available in the PowerShell Gallery. If it is not, it throws an error. If the module's version is lower than the LowestSupportedVersion, it throws an error. If the module is not installed, it installs the module.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md

#>
function Update-HydrationModuleToSupportedVersion {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Version]
        $LowestSupportedVersion,
        [Parameter(Mandatory = $false)]
        [string]
        $ModuleName = "EnterprisePolicyAsCode",
        [switch]
        $Interactive
    )
    # TODO: Add additional logic from https://github.com/JulianHayward/Azure-MG-Sub-Governance-Reporting/blob/master/pwsh/dev/functions/verifyModules3rd.ps1 and thank Julian for the good code.
    $InformationPreference = "Continue"
    $onlineModule = Find-Module -name $ModuleName -ErrorAction Stop
    if (!($onlineModule)) {
        Write-Error "Module $ModuleName not found in the PowerShell Gallery. Please install manually."
    }
    else {
        if ([System.Version]$onlineModule.Version -lt [System.Version]$LowestSupportedVersion) {
            Write-Error "Module $ModuleName latest version in the galleries available to Find-Module is $($onlineModule.Version), which will not satisfy requirements $LowestSupportedVersion as provided in parameter inputs. You may need to identify a new location for Find-Module to use in order to locate version $LowestSupportedVersion or later."
        }
    }
    $latestVersion = ((Get-module -name $ModuleName -list | Sort-Object "Version" -Descending)[0]).Version
    if (!($latestVersion)) {
        Write-Information "Installing $ModuleName module..."
        try {
            Install-Module -name $ModuleName -Force -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to update $ModuleName module. Please update manually."
        }
    }
    else {
        if ([System.Version]$latestVersion -lt [System.Version]$lowestSupportedVersion) {
            Write-Information "Updating $ModuleName module..."
            try {
                Update-Module -name $ModuleName -Force -ErrorAction Stop
            }
            catch {
                Write-Error "Failed to update $ModuleName module. Please update manually."
            }
            
        }
        else {
            if (!($Interactive)) {
                Write-Information "$ModuleName module is already installed and meets required version."
            }
            else {
                $updateLocal = Read-Host "$ModuleName module is already installed and meets required version. If you would like to test for an update, reply 'Y', otherwise press enter to continue."
                if ($updateLocal -eq "Y") {
                    Write-Information "Updating $ModuleName module..."
                    try {
                        Update-Module -name $ModuleName -Force -ErrorAction Stop
                    }
                    catch {
                        Write-Error "Failed to update $ModuleName module. Please update manually."
                    }
                }
            }
        }
    }
}