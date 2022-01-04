#Requires -PSEdition Core

function Initialize-Environment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)] [hashtable] $EnvironmentDefinitions,
        [parameter(Mandatory = $false)] [string] $environmentSelector = $null
    )
        
    $environment = $null
    if ($environmentSelector -ne "") {
        if ($EnvironmentDefinitions.ContainsKey($environmentSelector)) {
            # valid input
            $environment = $EnvironmentDefinitions[$environmentSelector]
            Write-Information "==================================================================================================="
            Write-Information "Environment Selected"
            Write-Information "==================================================================================================="
        }
        else {
            Throw "Policy as Code environment selection $environmentSelector is not valid"
        }
    }
    else {
        $InformationPreference = "Continue"
        Write-Information "==================================================================================================="
        Write-Information "Select Environment"
        Write-Information "==================================================================================================="

        while ($null -eq $environment) {
            $environmentSelector = Read-Host "Enter environment name (not case senitive - must be dev1, dev2, qa, or prod)"
            if ($EnvironmentDefinitions.ContainsKey($environmentSelector)) {
                # valid input
                $environment = $EnvironmentDefinitions[$environmentSelector]
            }
        }
    }
    Write-Information "Environment = $($environment | ConvertTo-Json -Depth 100)"
    Write-Information ""
    Write-Information ""

    return $environment
}
