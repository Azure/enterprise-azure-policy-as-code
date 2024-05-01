<#
.SYNOPSIS
    This function creates a new EPAC Global Settings File.

.DESCRIPTION
    The New-HydrationGlobalSettingsFile function creates a new Hydration Global Settings File based on the provided parameters. It takes three parameters: AnswerFilePath, Answers, and RepoRootPath.

.PARAMETER AnswerFilePath
    The path to the Answer file, which is generated using the New-HydrationAnswerFile function.

.PARAMETER Answers
    The hashtable of answers. This parameter consumes the file output by New-HydrationAnswerFIle.

.PARAMETER RepoRootPath
    The root path of the repository. This parameter is mandatory.

.EXAMPLE
    New-HydrationGlobalSettingsFile -AnswerFilePath "./AnswerFile.txt" -RepoRootPath "./Repo"

    This example creates a new Hydration Global Settings File using the Answer file at "./AnswerFile.txt" and the repository at "./Repo".

.NOTES
    The function first checks if the Definitions directory exists in the repository. If it does not, it creates the directory. It then reads the Answer file and converts it to a hashtable. It then creates the Global Settings object by iterating over the environments in the answers.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'AnswerFile')]
    [string]
    $AnswerFilePath,
    [Parameter(Mandatory = $true, ParameterSetName = 'Answers')]
    [System.Management.Automation.OrderedHashtable]
    $Answers,
    [Parameter(Mandatory = $true)]
    $RepoRootPath
)
$InformationPreference = "Continue"
$mgBaseString = "/providers/Microsoft.Management/managementGroups/"
$definitionsPath = Join-Path $RepoRootPath "Definitions"
if (!(Test-Path $definitionsPath)) {
    New-HydrationDefinitionFolder -DefinitionsRootFolder $definitionsPath
}
if ($AnswerFilePath) {
    $Answers = Get-Content $AnswerFilePath -Encoding ascii | convertfrom-json -Depth 10 -AsHashtable
}
# Test to see if we need an exclusion for the epac root group
Write-Information "`nCreating Global Settings..."
# Build GlobalSettings object
$environmentBlock = @()
foreach ($env in $answers.environments.Keys) {
    $ebEntry = [ordered]@{
        pacSelector             = $answers.environments.$env.pacSelector
        cloud                   = $answers.environments.$env.cloud
        tenantId                = $answers.environments.$env.tenantId
        deploymentRootScope     = $($mgBaseString + $answers.environments.$env.intermediateRootGroupName)
        desiredState            = @{
            strategy                     = $answers.environments.$env.strategy
            keepDfcSecurityAssignments   = $false
            excludedScopes               = @() # TODO: No setting support yet
            excludedPolicyDefinitions    = @() # TODO: No setting support yet
            excludedPolicySetDefinitions = @() # TODO: No setting support yet
            excludedPolicyAssignments    = @() # TODO: No setting support yet
        }
        globalNotScopes         = @() # TODO: No setting support yet
        managedIdentityLocation = $answers.managedIdentityLocations
        # keepDfcSecurityAssignments = $false # Old location
    }
    $environmentBlock += $ebEntry
}
$globalSettings = [ordered]@{
    '$schema'       = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
    pacOwnerId      = $answers.pacOwnerId
    pacEnvironments = $environmentBlock
}
$globalSettingsPath = Join-Path $definitionsPath "global-settings.jsonc"
Write-Information "Writing Global Settings to $globalSettingsPath`n"
if (!(test-path $(Split-Path $globalSettingsPath))) {
    New-Item -ItemType Directory -Path $definitionsPath -Force
}
$globalSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $globalSettingsPath -Encoding ascii -Force
return $globalSettings
