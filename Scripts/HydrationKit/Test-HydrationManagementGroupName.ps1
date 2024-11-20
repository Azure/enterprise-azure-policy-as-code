<#
.SYNOPSIS
This function tests if a given Management Group name is valid given Azure's naming requirements.

.DESCRIPTION
The function checks if the provided Management Group name is valid. A valid name does not contain any of the following characters: /, ?, #. Additionally, the name must be 90 characters or less in length.

.PARAMETER ManagementGroupName
The name of the Management Group to be validated.

.EXAMPLE
Test-HydrationManagementGroupName -ManagementGroupName "ValidName"

This will return $true if "ValidName" is a valid Management Group name, and $false otherwise.

.NOTES
The function uses the Select-String cmdlet to match the Management Group name against a regular expression pattern. It also checks the length of the name.

.LINK
https://aka.ms/epac
https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function Test-HydrationManagementGroupName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The name of the Management Group to be validated.")]
        [string]
        $ManagementGroupName
    )
    $isValid = $ManagementGroupName | Select-String -Pattern "^[a-zA-Z0-9\-_\.\(\)]+$" -Quiet
    if ($isValid -and $ManagementGroupName.Length -le 90) {
        Write-Debug "Management Group `"$ManagementGroupName `" name is valid."
        return $true
    }
    else {
        Write-Debug "Management Group `"$ManagementGroupName `" name is invalid."
        return $false
    }
}