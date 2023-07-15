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

    $pacEnvironment = $null
    $pacEnvironments = $globalSettings.pacEnvironments
    if ($PacEnvironmentSelector -eq "") {
        # Interactive
        $InformationPreference = "Continue"
        $Interactive = $true
        if ($pacEnvironments.Count -eq 1) {
            $pacEnvironment = @{} # Build hashtable for single PAC environment
            $pacEnvironments.Values.Keys | Foreach-Object {
                $pacEnvironment.Add($_, $pacEnvironments.Values.$_)
            }
        }
        else {
            $prompt = $globalSettings.pacEnvironmentPrompt
            while ($null -eq $pacEnvironment) {
                $PacEnvironmentSelector = Read-Host "Select Policy as Code environment [$prompt]"
                if ($pacEnvironments.ContainsKey($PacEnvironmentSelector)) {
                    # valid input
                    $pacEnvironment = $pacEnvironments[$PacEnvironmentSelector]
                }
                else {
                    Write-Information "Invalid selection entered."
                }
            }
        }
    }
    else {
        if ($pacEnvironments.ContainsKey($PacEnvironmentSelector)) {
            # valid input
            $pacEnvironment = $pacEnvironments[$PacEnvironmentSelector]
        }
        else {
            Write-Error "Policy as Code environment selector $PacEnvironmentSelector is not valid" -ErrorAction Stop
        }
    }
    Write-Information "Environment Selected: $PacEnvironmentSelector"
    Write-Information "    cloud      = $($pacEnvironment.cloud)"
    Write-Information "    tenant     = $($pacEnvironment.tenantId)"
    Write-Information "    root scope = $($pacEnvironment.deploymentRootScope)"
    Write-Information ""


    $OutputFolder = $globalSettings.outputFolder
    $InputFolder = $globalSettings.inputFolder
    $pacEnvironmentDefinition = $pacEnvironment + $globalSettings + @{
        interactive          = $Interactive
        policyPlanOutputFile = "$($OutputFolder)/plans-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanOutputFile  = "$($OutputFolder)/plans-$PacEnvironmentSelector/roles-plan.json"
        policyPlanInputFile  = "$($InputFolder)/plans-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanInputFile   = "$($InputFolder)/plans-$PacEnvironmentSelector/roles-plan.json"

    }
    return $pacEnvironmentDefinition
}
