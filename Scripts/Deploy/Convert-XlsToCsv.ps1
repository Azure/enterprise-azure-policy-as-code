#Requires -PSEdition Core

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder
)

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"

$folders = Get-PacFolders -definitionsRootFolder $definitionsRootFolder
$InformationPreference = "Continue"

$folders = Get-PacFolders -definitionsRootFolder $definitionsRootFolder
$InformationPreference = "Continue"

$importExcelModuleNotInstalled = $null -eq (Get-InstalledModule ImportExcel -ErrorVariable importExcelModuleNotInstalled)
if ($importExcelModuleNotInstalled) {
    Write-Information "==================================================================================================="
    Write-Information "Installing ImportExcel from PowerShell Gallery: https://www.powershellgallery.com/packages/ImportExcel"
    Write-Information "==================================================================================================="
    $result = Install-Module -Name ImportExcel -Force -PassThru -ErrorAction Continue
    if ($null -eq $result) {
        Write-Error "Install-Module for ImportExcel failed. You cannot use .xlsx files in your environment. Use csv files instead" -ErrorAction Stop
    }
}

Write-Information "==================================================================================================="
Write-Information "Converting definition Excel files (.xlsx) in folder '$definitionsRootFolder' too CSV"
Write-Information "==================================================================================================="

$excelFiles = @() + (Get-ChildItem -Path $folders.definitionsRootFolder -Recurse -File -Filter "*.xlsx")

foreach ($excelFile  in $excelFiles) {
    $excelFileFullName = $excelFile.fullName
    Write-Information $excelFileFullName
    $excelArray = Import-Excel -LiteralPath $excelFileFullName -ErrorAction Stop

    $csvFileFullName = $excelFileFullName -replace '\.xlsx$', '.csv'
    $excelArray | ConvertTo-Csv -UseQuotes AsNeeded -NoTypeInformation | Out-File $csvFileFullName -Force
}
