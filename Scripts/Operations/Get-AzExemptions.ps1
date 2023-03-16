#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -interactive $pacEnvironment.interactive

$outputPath = "$($pacEnvironment.outputFolder)/Exemptions/$($pacEnvironment.pacEnvironmentSelector)"
if (-not (Test-Path $outputPath)) {
    New-Item $outputPath -Force -ItemType directory
}

$scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
$deployedPolicyResources = Get-AzPolicyResources -pacEnvironment $pacEnvironment -scopeTable $scopeTable -skipRoleAssignments
$exemptions = $deployedPolicyResources.policyExemptions.managed
$assignments = $deployedPolicyResources.policyassignments.managed

$numberOfExemptions = $exemptions.Count
Write-Information "==================================================================================================="
Write-Information "Output Exemption list ($numberOfExemptions)"
Write-Information "==================================================================================================="

$exemptionsResult = Confirm-ActiveAzExemptions -exemptions $exemptions -assignments $assignments
$policyDefinitionReferenceIdsTransform = @{label = "policyDefinitionReferenceIds"; expression = { ($_.policyDefinitionReferenceIds -join ",").ToString() } }
$metadataTransform = @{label = "metadata"; expression = { IF ($_.metadata) { (ConvertTo-Json $_.metadata -Depth 100 -Compress).ToString() } Else { '' } } }
$expiresInDaysTransform = @{label = "expiresInDays"; expression = { IF ($_.expiresInDays -eq [Int32]::MaxValue) { 'n/a' } Else { $_.expiresInDays } } }
foreach ($key in $exemptionsResult.Keys) {
    [hashtable] $exemptions = $exemptionsResult.$key
    Write-Information "Output $key Exemption list ($($exemptions.Count))"

    $valueArray = @() + $exemptions.Values

    if ($valueArray.Count -gt 0) {

        $stem = "$outputPath/$($key)-exemptions"

        # JSON Output
        $jsonArray = @() + $valueArray | Select-Object -Property `
            name, `
            displayName, `
            description, `
            exemptionCategory, `
            expiresOn, `
            status, `
            $expiresInDaysTransform, `
            scope, `
            policyAssignmentId, `
            policyDefinitionReferenceIds, `
            metadata
        $jsonFile = "$($stem).json"
        if (Test-Path $jsonFile) {
            Remove-Item $jsonFile
        }
        $outputJson = @{
            exemptions = @($jsonArray)
        }
        ConvertTo-Json $outputJson -Depth 100 | Out-File $jsonFile -Force

        # Spreadsheet outputs (CSV)
        $excelArray = @() + $valueArray | Select-Object -Property `
            name, `
            displayName, `
            description, `
            exemptionCategory, `
            expiresOn, `
            status, `
            $expiresInDaysTransform, `
            scope, `
            policyAssignmentId, `
            $policyDefinitionReferenceIdsTransform, `
            $metadataTransform

        $csvFile = "$($stem).csv"
        if (Test-Path $csvFile) {
            Remove-Item $csvFile
        }
        $excelArray | ConvertTo-Csv -UseQuotes AsNeeded | Out-File $csvFile -Force
    }
}
