<#
.SYNOPSIS
    Install and configure the EPAC MCP Server for AI-assisted Azure Policy management.

.DESCRIPTION
    Downloads the EPAC MCP Server from GitHub, installs it to a shared location
    (~/.epac/mcp-server), registers it as a Python package, and automatically detects
    your environment (VS Code or terminal/Copilot CLI) to generate the appropriate
    MCP configuration.

    After installation, 'python -m epac_mcp' works globally without any PYTHONPATH
    configuration — the package is installed into the Python environment via pip.

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

.PARAMETER Target
    Force a specific configuration target: "vscode", "copilot-cli", or "auto" (default).
    When "auto", the script detects whether it is running inside VS Code or a plain terminal.

.EXAMPLE
    .\Install-EpacMcpServer.ps1 -DefinitionsRootFolder ./Definitions -PacEnvironmentSelector "EPAC-DEV"

.EXAMPLE
    .\Install-EpacMcpServer.ps1 -DefinitionsRootFolder C:\policy\Definitions -PacEnvironmentSelector "Tenant" -Target copilot-cli
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to your EPAC Definitions folder.")]
    [string] $DefinitionsRootFolder,

    [Parameter(Mandatory = $true, HelpMessage = "The pacSelector value to target.")]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Output folder for plan files.")]
    [string] $OutputFolder = "./Output",

    [Parameter(Mandatory = $false, HelpMessage = "Target environment: 'auto', 'vscode', or 'copilot-cli'.")]
    [ValidateSet("auto", "vscode", "copilot-cli")]
    [string] $Target = "auto"
)

$ErrorActionPreference = "Stop"

# --- Preflight checks ---
Write-Host "`n=== EPAC MCP Server Installer ===" -ForegroundColor Cyan

# Check Python — resolve the real executable path (not the Windows Store stub)
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Error "Python 3.10+ is required but not found on PATH. Install from https://python.org"
    return
}
$pyVersion = & python --version 2>&1
$pythonRealPath = (& python -c "import sys; print(sys.executable)" 2>&1).Trim()
Write-Host "[OK] $pyVersion ($pythonRealPath)" -ForegroundColor Green

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

# Check Az PowerShell module
$azModule = Get-Module -ListAvailable Az.Resources -ErrorAction SilentlyContinue
if (-not $azModule) {
    Write-Warning "Az.Resources module not found. Install with: Install-Module Az -Scope CurrentUser"
    Write-Warning "The search_builtin_policies tool requires Az.Resources and Connect-AzAccount."
}
else {
    Write-Host "[OK] Az.Resources module available ($($azModule.Version))" -ForegroundColor Green
}

# --- Download MCP server source to shared location ---
Write-Host "`nDownloading EPAC MCP Server..." -ForegroundColor Cyan

$repoUrl = "https://github.com/Azure/enterprise-azure-policy-as-code"
$branch = "main"
$serverFiles = @(
    "Tools/mcp-server/pyproject.toml",
    "Tools/mcp-server/epac_mcp/__init__.py",
    "Tools/mcp-server/epac_mcp/__main__.py",
    "Tools/mcp-server/epac_mcp/config.py",
    "Tools/mcp-server/epac_mcp/runners.py",
    "Tools/mcp-server/epac_mcp/server.py"
)

# Install to ~/.epac/mcp-server (shared across all projects)
$mcpDir = Join-Path $HOME ".epac" "mcp-server"
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

# --- Install as a Python package (globally available, no PYTHONPATH needed) ---
Write-Host "`nInstalling Python package..." -ForegroundColor Cyan
& python -m pip install -e $mcpDir --quiet 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    & python -m pip install -e $mcpDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Python dependencies."
        return
    }
}

# Verify the package is importable
& python -c "from epac_mcp.server import mcp; print('Package OK')" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Package installed but import failed. Check Python environment."
    return
}
Write-Host "[OK] Package installed - 'python -m epac_mcp' is now available globally" -ForegroundColor Green

# --- Write config.json into the installed package directory ---
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
    definitions_root = $defsPath.Replace("\", "/")
    pac_selector     = $PacEnvironmentSelector
    output_folder    = $resolvedOutput.Replace("\", "/")
    epac_module_path = $null
} | ConvertTo-Json -Depth 2

$configPath = Join-Path $mcpDir "config.json"
Set-Content -Path $configPath -Value $config
Write-Host "[OK] Config written to $configPath" -ForegroundColor Green

# --- Detect environment ---
Write-Host "`nDetecting environment..." -ForegroundColor Cyan

$detectedTargets = @()

if ($Target -eq "auto" -or $Target -eq "vscode") {
    # Detect VS Code: TERM_PROGRAM, VSCODE_* env vars, or .vscode/ folder exists
    $inVsCode = ($env:TERM_PROGRAM -eq "vscode") -or
    ($null -ne $env:VSCODE_PID) -or
    ($null -ne $env:VSCODE_CWD) -or
    ($null -ne $env:VSCODE_GIT_IPC_HANDLE) -or
    (Test-Path (Join-Path (Get-Location) ".vscode"))

    if ($Target -eq "vscode" -or ($Target -eq "auto" -and $inVsCode)) {
        $detectedTargets += "vscode"
    }
}

if ($Target -eq "auto" -or $Target -eq "copilot-cli") {
    # Detect Copilot CLI: check if the copilot command exists
    $copilotCmd = Get-Command copilot -ErrorAction SilentlyContinue
    if ($Target -eq "copilot-cli" -or ($Target -eq "auto" -and $copilotCmd)) {
        $detectedTargets += "copilot-cli"
    }
}

# If auto detected nothing, default to both so the user gets at least one config
if ($detectedTargets.Count -eq 0) {
    Write-Host "  Could not auto-detect environment. Configuring both VS Code and Copilot CLI." -ForegroundColor Yellow
    $detectedTargets = @("vscode", "copilot-cli")
}
else {
    Write-Host "  Detected: $($detectedTargets -join ', ')" -ForegroundColor Green
}

# --- Configure VS Code ---
if ($detectedTargets -contains "vscode") {
    Write-Host "`nConfiguring VS Code (.vscode/mcp.json)..." -ForegroundColor Cyan

    $vscodePath = Join-Path (Get-Location) ".vscode"
    New-Item -ItemType Directory -Path $vscodePath -Force | Out-Null

    $vscodeMcpConfig = @{
        servers = @{
            epac = @{
                type    = "stdio"
                command = $pythonRealPath.Replace("\", "/")
                args    = @("-m", "epac_mcp")
                env     = @{
                    EPAC_DEFINITIONS_ROOT = $defsPath.Replace("\", "/")
                    EPAC_PAC_SELECTOR     = $PacEnvironmentSelector
                    EPAC_OUTPUT_FOLDER    = $resolvedOutput.Replace("\", "/")
                }
            }
        }
    } | ConvertTo-Json -Depth 4

    $mcpJsonPath = Join-Path $vscodePath "mcp.json"
    Set-Content -Path $mcpJsonPath -Value $vscodeMcpConfig
    Write-Host "[OK] VS Code config written to $mcpJsonPath" -ForegroundColor Green
}

# --- Configure Copilot CLI ---
if ($detectedTargets -contains "copilot-cli") {
    Write-Host "`nConfiguring GitHub Copilot CLI (~/.copilot/config.json)..." -ForegroundColor Cyan

    $copilotDir = Join-Path $HOME ".copilot"
    New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null

    $copilotConfigPath = Join-Path $copilotDir "config.json"

    # Load existing config to preserve other settings
    $copilotConfig = @{}
    if (Test-Path $copilotConfigPath) {
        try {
            $copilotConfig = Get-Content $copilotConfigPath -Raw | ConvertFrom-Json -AsHashtable
            Write-Host "  Merging with existing Copilot CLI config" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Could not parse existing $copilotConfigPath - backing up and creating new"
            Copy-Item $copilotConfigPath "$copilotConfigPath.bak" -Force
            $copilotConfig = @{}
        }
    }

    # Clean up any stale lowercase "mcpservers" key (PowerShell hashtables are case-insensitive
    # but JSON is not — previous runs may have written a lowercase variant that conflicts)
    $staleKeys = @($copilotConfig.Keys | Where-Object { $_ -ieq "mcpServers" -and $_ -cne "mcpServers" })
    foreach ($key in $staleKeys) {
        $copilotConfig.Remove($key)
        Write-Host "  Removed stale key '$key' (wrong case)" -ForegroundColor Yellow
    }

    # Ensure mcpServers key exists
    if (-not $copilotConfig.ContainsKey("mcpServers")) {
        $copilotConfig["mcpServers"] = @{}
    }

    # Add/update the epac server entry — no PYTHONPATH needed, pip install handles it
    $copilotConfig["mcpServers"]["epac"] = @{
        type    = "stdio"
        command = $pythonRealPath.Replace("\", "/")
        args    = @("-m", "epac_mcp")
        env     = @{
            EPAC_DEFINITIONS_ROOT = $defsPath.Replace("\", "/")
            EPAC_PAC_SELECTOR     = $PacEnvironmentSelector
            EPAC_OUTPUT_FOLDER    = $resolvedOutput.Replace("\", "/")
        }
    }

    $copilotConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $copilotConfigPath
    Write-Host "[OK] Copilot CLI config written to $copilotConfigPath" -ForegroundColor Green
}

# --- Done ---
Write-Host "`n=== Installation Complete ===" -ForegroundColor Green

$nextSteps = @("  MCP Server installed to: $mcpDir", "  Server config:           $configPath", "  Package: python -m epac_mcp (available globally)", "")

if ($detectedTargets -contains "vscode") {
    $nextSteps += @(
        "  VS Code:",
        "    1. Open this folder in VS Code",
        "    2. The EPAC MCP server will appear in the Copilot Chat MCP panel",
        "    3. Click Start to enable the tools",
        ""
    )
}
if ($detectedTargets -contains "copilot-cli") {
    $nextSteps += @(
        "  Copilot CLI:",
        "    1. Run: copilot",
        "    2. Type: /mcp  -- you should see 'epac' with 7 tools",
        ""
    )
}
$nextSteps += @(
    "  Try: `"Search for policies related to storage account encryption`"",
    ""
)

Write-Host ($nextSteps -join "`n") -ForegroundColor White


