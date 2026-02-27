<#
.SYNOPSIS
    Install and configure the EPAC MCP Server for AI-assisted Azure Policy management.

.DESCRIPTION
    Downloads the EPAC MCP Server from GitHub and installs it locally, then generates a
    .vscode/mcp.json configuration file so VS Code Copilot Chat can use the server tools.

    The MCP server enables natural-language-driven policy management:
    - Search Azure built-in policies
    - Create EPAC policy assignments and definitions
    - Run Build-DeploymentPlans and Deploy-PolicyPlan

.PARAMETER DefinitionsRootFolder
    Path to your EPAC Definitions folder (containing global-settings.jsonc).

.PARAMETER PacEnvironmentSelector
    The pacSelector value from your global settings to target.

.PARAMETER OutputFolder
    Where EPAC writes plan files. Defaults to ./Output.

.PARAMETER InstallPath
    Where to install the MCP server. Defaults to ~/.epac-mcp-server.

.PARAMETER SkipVsCodeConfig
    Skip generating .vscode/mcp.json in the current directory.

.EXAMPLE
    .\Install-EpacMcpServer.ps1 -DefinitionsRootFolder ./Definitions -PacEnvironmentSelector "EPAC-DEV"

.EXAMPLE
    .\Install-EpacMcpServer.ps1 -DefinitionsRootFolder C:\policy\Definitions -PacEnvironmentSelector "Tenant" -OutputFolder C:\policy\Output
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to your EPAC Definitions folder.")]
    [string] $DefinitionsRootFolder,

    [Parameter(Mandatory = $true, HelpMessage = "The pacSelector value to target.")]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Output folder for plan files.")]
    [string] $OutputFolder = "./Output",

    [Parameter(Mandatory = $false, HelpMessage = "Where to install the MCP server.")]
    [string] $InstallPath = (Join-Path $HOME ".epac-mcp-server"),

    [Parameter(Mandatory = $false, HelpMessage = "Skip generating .vscode/mcp.json.")]
    [switch] $SkipVsCodeConfig
)

$ErrorActionPreference = "Stop"

# --- Preflight checks ---
Write-Host "`n=== EPAC MCP Server Installer ===" -ForegroundColor Cyan

# Check Python
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Error "Python 3.10+ is required but not found on PATH. Install from https://python.org"
    return
}
$pyVersion = & python --version 2>&1
Write-Host "[OK] $pyVersion" -ForegroundColor Green

# Check pip
$pip = & python -m pip --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "pip is required but not available. Run: python -m ensurepip"
    return
}
Write-Host "[OK] pip available" -ForegroundColor Green

# Check PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "PowerShell 7+ is recommended for EPAC. Current: $($PSVersionTable.PSVersion)"
}

# Check az CLI
$az = Get-Command az -ErrorAction SilentlyContinue
if (-not $az) {
    Write-Warning "Azure CLI (az) not found. The search_builtin_policies tool will not work without it."
}

# --- Download MCP server source ---
Write-Host "`nDownloading EPAC MCP Server..." -ForegroundColor Cyan

$repoUrl = "https://github.com/Azure/enterprise-azure-policy-as-code"
$branch = "main"
$serverFiles = @(
    "Tools/mcp-server/pyproject.toml",
    "Tools/mcp-server/epac_mcp/__init__.py",
    "Tools/mcp-server/epac_mcp/config.py",
    "Tools/mcp-server/epac_mcp/runners.py",
    "Tools/mcp-server/epac_mcp/server.py"
)

# Create install directory
$mcpDir = $InstallPath
$mcpPkgDir = Join-Path $mcpDir "epac_mcp"
New-Item -ItemType Directory -Path $mcpPkgDir -Force | Out-Null

foreach ($file in $serverFiles) {
    $fileName = Split-Path $file -Leaf
    $rawUrl = "$repoUrl/raw/$branch/$file"

    if ($file -like "*/epac_mcp/*") {
        $destPath = Join-Path $mcpPkgDir $fileName
    }
    else {
        $destPath = Join-Path $mcpDir $fileName
    }

    try {
        Invoke-WebRequest -Uri $rawUrl -OutFile $destPath -UseBasicParsing
        Write-Host "  Downloaded: $fileName" -ForegroundColor Gray
    }
    catch {
        Write-Error "Failed to download $rawUrl : $_"
        return
    }
}

Write-Host "[OK] Server files downloaded to $mcpDir" -ForegroundColor Green

# --- Install Python dependencies ---
Write-Host "`nInstalling Python dependencies..." -ForegroundColor Cyan
& python -m pip install -e $mcpDir --quiet 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    # Retry without --quiet to show errors
    & python -m pip install -e $mcpDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Python dependencies."
        return
    }
}
Write-Host "[OK] Python dependencies installed" -ForegroundColor Green

# --- Write config.json ---
Write-Host "`nWriting configuration..." -ForegroundColor Cyan

$resolvedDefs = (Resolve-Path $DefinitionsRootFolder -ErrorAction SilentlyContinue)
if ($resolvedDefs) {
    $defsPath = $resolvedDefs.Path
}
else {
    $defsPath = $DefinitionsRootFolder
}

$resolvedOutput = $OutputFolder
if (Test-Path $OutputFolder) {
    $resolvedOutput = (Resolve-Path $OutputFolder).Path
}

$config = @{
    definitions_root  = $defsPath.Replace("\", "/")
    pac_selector      = $PacEnvironmentSelector
    output_folder     = $resolvedOutput.Replace("\", "/")
    epac_module_path  = $null
} | ConvertTo-Json -Depth 2

$configPath = Join-Path $mcpDir "config.json"
Set-Content -Path $configPath -Value $config
Write-Host "[OK] Config written to $configPath" -ForegroundColor Green

# --- Generate .vscode/mcp.json ---
if (-not $SkipVsCodeConfig) {
    Write-Host "`nGenerating .vscode/mcp.json..." -ForegroundColor Cyan

    $vscodePath = Join-Path (Get-Location) ".vscode"
    New-Item -ItemType Directory -Path $vscodePath -Force | Out-Null

    $mcpJson = @{
        servers = @{
            epac = @{
                type    = "stdio"
                command = "python"
                args    = @("-m", "epac_mcp.server")
                env     = @{
                    PYTHONPATH             = $mcpDir.Replace("\", "/")
                    EPAC_DEFINITIONS_ROOT  = $defsPath.Replace("\", "/")
                    EPAC_PAC_SELECTOR      = $PacEnvironmentSelector
                    EPAC_OUTPUT_FOLDER     = $resolvedOutput.Replace("\", "/")
                }
            }
        }
    } | ConvertTo-Json -Depth 4

    $mcpJsonPath = Join-Path $vscodePath "mcp.json"
    Set-Content -Path $mcpJsonPath -Value $mcpJson
    Write-Host "[OK] VS Code config written to $mcpJsonPath" -ForegroundColor Green
}

# --- Done ---
Write-Host "`n=== Installation Complete ===" -ForegroundColor Green
Write-Host @"

  MCP Server installed to: $mcpDir
  Config file:             $configPath

  Next steps:
    1. Open this folder in VS Code
    2. The EPAC MCP server will appear in the Copilot Chat MCP panel
    3. Click Start to enable the tools
    4. Try: "Search for policies related to storage account encryption"

  To test from the command line:
    `$env:PYTHONPATH = "$mcpDir"
    python -m epac_mcp.server

"@ -ForegroundColor White
