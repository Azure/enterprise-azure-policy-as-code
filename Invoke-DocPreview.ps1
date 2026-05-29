#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Hosts a local preview of the EPAC documentation site using MkDocs.

.DESCRIPTION
    Serves the MkDocs documentation site locally so you can preview changes
    before they are published to https://azure.github.io/enterprise-azure-policy-as-code/

    Requires: pip install mkdocs mkdocs-material

.PARAMETER Port
    Port to serve on. Defaults to 8080.

.PARAMETER Address
    Address to bind to. Defaults to 127.0.0.1 (localhost only).
    Use 0.0.0.0 to expose on all interfaces (e.g. for remote access).

.EXAMPLE
    .\Invoke-DocPreview.ps1
    Serves on http://127.0.0.1:8080/enterprise-azure-policy-as-code/

.EXAMPLE
    .\Invoke-DocPreview.ps1 -Address 0.0.0.0 -Port 9000
    Serves on all interfaces at port 9000.
#>
[CmdletBinding()]
param(
    [int]$Port = 8080,
    [string]$Address = "127.0.0.1"
)

$ErrorActionPreference = "Stop"

# Verify pip is available
if (-not (Get-Command pip -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ERROR: pip is not installed or not in PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Python (which includes pip) from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "  or on Linux/macOS:" -ForegroundColor Yellow
    Write-Host "    sudo apt install python3-pip   # Debian/Ubuntu" -ForegroundColor Cyan
    Write-Host "    brew install python            # macOS" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Verify mkdocs is available; if not, offer the install command
if (-not (Get-Command mkdocs -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ERROR: mkdocs is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "    pip install mkdocs mkdocs-material" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Move to repo root (script location)
Set-Location $PSScriptRoot

$url = "http://$Address`:$Port/enterprise-azure-policy-as-code/"
Write-Host ""
Write-Host "Starting EPAC docs preview..." -ForegroundColor Cyan
Write-Host "  URL: $url" -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

mkdocs serve --dev-addr "$Address`:$Port"
