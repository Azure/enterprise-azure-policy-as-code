#Requires -PSEdition Core

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$definitionsRootFolder
)

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"

$folders = Get-PacFolders -definitionsRootFolder $definitionsRootFolder
$InformationPreference = "Continue"

[bool] $importExcelModuleNotInstalled = $null -eq (Get-InstalledModule ImportExcel -ErrorAction SilentlyContinue)
if ($importExcelModuleNotInstalled) {
    Write-Information "==================================================================================================="
    Write-Information "Installing ImportExcel from PowerShell Gallery: https://www.powershellgallery.com/packages/ImportExcel"
    Write-Information "==================================================================================================="
    $result = Install-Module -Name ImportExcel -Force -PassThru
    if ($null -eq $result) {
        Write-Error "Install-Module for ImportExcel failed. You cannot use .xlsx files in your environment. Use csv files instead" -ErrorAction Stop
    }
}

Write-Information "==================================================================================================="
Write-Information "Converting definition Excel files (.xlsx) in folder '$definitionsRootFolder' too CSV"
Write-Information "==================================================================================================="

$definitionsRootFolder = $folders.definitionsRootFolder
$excelFiles = @() + (Get-ChildItem -Path $definitionsRootFolder -Recurse -File -Filter "*.xlsx")

foreach ($excelFile  in $excelFiles) {
    $excelFileFullName = $excelFile.fullName
    Write-Information $excelFileFullName
    $excelArray = Import-Excel $excelFileFullName -ErrorAction Stop

    $csvFileFullName = $excelFileFullName -replace '\.xlsx$', '.csv'
    $excelArray | ConvertTo-Csv -UseQuotes AsNeeded | Out-File $csvFileFullName -Force
}
Write-Information ""
