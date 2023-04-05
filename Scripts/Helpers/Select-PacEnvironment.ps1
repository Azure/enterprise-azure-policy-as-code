function Select-PacEnvironment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false, Position = 0)] [string] $pacEnvironmentSelector,
        [Parameter(Mandatory = $false)] [string] $definitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $outputFolder,
        [Parameter(Mandatory = $false)] [string] $inputFolder,
        [Parameter(Mandatory = $false)] [bool] $interactive = $false
    )

    $globalSettings = Get-GlobalSettings -definitionsRootFolder $definitionsRootFolder -outputFolder $outputFolder -inputFolder $inputFolder

    $pacEnvironment = $null
    $pacEnvironments = $globalSettings.pacEnvironments
    if ($pacEnvironmentSelector -eq "") {
        # Interactive
        $InformationPreference = "Continue"
        $interactive = $true
        if ($pacEnvironments.Count -eq 1) {
            $pacEnvironment = @{} # Build hashtable for single PAC environment
            $pacEnvironments.Values.Keys | Foreach-Object {
                $pacEnvironment.Add($_, $pacEnvironments.Values.$_)
            }
        }
        else {
            $prompt = $globalSettings.pacEnvironmentPrompt
            while ($null -eq $pacEnvironment) {
                $pacEnvironmentSelector = Read-Host "Select Policy as Code environment [$prompt]"
                if ($pacEnvironments.ContainsKey($pacEnvironmentSelector)) {
                    # valid input
                    $pacEnvironment = $pacEnvironments[$pacEnvironmentSelector]
                }
                else {
                    Write-Information "Invalid selection entered."
                }
            }
        }
    }
    else {
        if ($pacEnvironments.ContainsKey($pacEnvironmentSelector)) {
            # valid input
            $pacEnvironment = $pacEnvironments[$pacEnvironmentSelector]
        }
        else {
            Write-Error "Policy as Code environment selector $pacEnvironmentSelector is not valid" -ErrorAction Stop
        }
    }
    Write-Information "Environment Selected: $pacEnvironmentSelector"
    Write-Information "    cloud      = $($pacEnvironment.cloud)"
    Write-Information "    tenant     = $($pacEnvironment.tenantId)"
    Write-Information "    root scope = $($pacEnvironment.deploymentRootScope)"
    Write-Information ""


    $outputFolder = $globalSettings.outputFolder
    $inputFolder = $globalSettings.inputFolder
    $pacEnvironmentDefinition = $pacEnvironment + $globalSettings + @{
        interactive          = $interactive
        policyPlanOutputFile = "$($outputFolder)/plans-$pacEnvironmentSelector/policy-plan.json"
        rolesPlanOutputFile  = "$($outputFolder)/plans-$pacEnvironmentSelector/roles-plan.json"
        policyPlanInputFile  = "$($inputFolder)/plans-$pacEnvironmentSelector/policy-plan.json"
        rolesPlanInputFile   = "$($inputFolder)/plans-$pacEnvironmentSelector/roles-plan.json"

    }
    return $pacEnvironmentDefinition
}
