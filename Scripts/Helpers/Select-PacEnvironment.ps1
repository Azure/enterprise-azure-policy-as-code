function Select-PacEnvironment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector,
        [Parameter(Mandatory = $false)] [string] $DefinitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $OutputFolder,
        [Parameter(Mandatory = $false)] [string] $InputFolder,
        [Parameter(Mandatory = $false)] [bool] $Interactive = $false
    )

    $globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -InputFolder $InputFolder

    $PacEnvironment = $null
    $PacEnvironments = $globalSettings.pacEnvironments
    if ($PacEnvironmentSelector -eq "") {
        # Interactive
        $InformationPreference = "Continue"
        $Interactive = $true
        if ($PacEnvironments.Count -eq 1) {
            $PacEnvironment = @{} # Build hashtable for single PAC environment
            $PacEnvironments.Values.Keys | Foreach-Object {
                $PacEnvironment.Add($_, $PacEnvironments.Values.$_)
            }
        }
        else {
            $prompt = $globalSettings.pacEnvironmentPrompt
            while ($null -eq $PacEnvironment) {
                $PacEnvironmentSelector = Read-Host "Select Policy as Code environment [$prompt]"
                if ($PacEnvironments.ContainsKey($PacEnvironmentSelector)) {
                    # valid input
                    $PacEnvironment = $PacEnvironments[$PacEnvironmentSelector]
                }
                else {
                    Write-Information "Invalid selection entered."
                }
            }
        }
    }
    else {
        if ($PacEnvironments.ContainsKey($PacEnvironmentSelector)) {
            # valid input
            $PacEnvironment = $PacEnvironments[$PacEnvironmentSelector]
        }
        else {
            Write-Error "Policy as Code environment selector $PacEnvironmentSelector is not valid" -ErrorAction Stop
        }
    }
    Write-Information "Environment Selected: $PacEnvironmentSelector"
    Write-Information "    cloud      = $($PacEnvironment.cloud)"
    Write-Information "    tenant     = $($PacEnvironment.tenantId)"
    Write-Information "    root scope = $($PacEnvironment.deploymentRootScope)"
    Write-Information ""


    $OutputFolder = $globalSettings.outputFolder
    $InputFolder = $globalSettings.inputFolder
    $PacEnvironmentDefinition = $PacEnvironment + $globalSettings + @{
        interactive          = $Interactive
        policyPlanOutputFile = "$($OutputFolder)/plans-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanOutputFile  = "$($OutputFolder)/plans-$PacEnvironmentSelector/roles-plan.json"
        policyPlanInputFile  = "$($InputFolder)/plans-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanInputFile   = "$($InputFolder)/plans-$PacEnvironmentSelector/roles-plan.json"

    }
    return $PacEnvironmentDefinition
}
