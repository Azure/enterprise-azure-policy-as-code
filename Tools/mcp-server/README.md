# EPAC MCP Server

A Model Context Protocol (MCP) server that wraps [Enterprise Azure Policy as Code (EPAC)](https://aka.ms/epac) PowerShell commands as AI-callable tools.

## What It Does

Enables natural-language-driven Azure Policy management:

> "Create a policy assignment to require encryption on storage accounts"

The server will:
1. **Search** Azure built-in policies for matching definitions
2. **Create** EPAC-compliant policy assignment JSON files
3. **Plan** the deployment via `Build-DeploymentPlans`
4. **Deploy** the changes via `Deploy-PolicyPlan`

## Prerequisites

- Python 3.10+
- PowerShell 7.0+ with the `EnterprisePolicyAsCode` module installed
- Azure CLI (`az`) authenticated to your tenant
- An existing EPAC definitions folder with `global-settings.jsonc`

## Setup

### 1. Install Python dependencies

```bash
cd Tools/mcp-server
pip install -e .
```

### 2. Configure

The server is configured via environment variables (set in `.vscode/mcp.json`) or a `config.json` file:

| Variable | Description | Default |
|----------|-------------|---------|
| `EPAC_DEFINITIONS_ROOT` | Path to your EPAC Definitions folder | — |
| `EPAC_PAC_SELECTOR` | The `pacSelector` value to target | — |
| `EPAC_OUTPUT_FOLDER` | Where EPAC writes plan files | `./Output` |
| `EPAC_MODULE_PATH` | Path to EPAC module source (if not from PSGallery) | `null` |

Alternatively, copy `config.example.json` to `config.json` in this directory.

### 3. VS Code (automatic)

The repo ships with `.vscode/mcp.json` which registers the server automatically.
Open the EPAC repo in VS Code → the server appears in the Copilot Chat MCP panel.

Update `EPAC_DEFINITIONS_ROOT` and `EPAC_PAC_SELECTOR` in `.vscode/mcp.json` to match your environment.

### Other MCP clients (Claude Desktop, Copilot CLI, etc.)

```json
{
    "mcpServers": {
        "epac": {
            "command": "python",
            "args": ["-m", "epac_mcp.server"],
            "env": {
                "PYTHONPATH": "/path/to/epac-repo/Tools/mcp-server",
                "EPAC_DEFINITIONS_ROOT": "/path/to/your/Definitions",
                "EPAC_PAC_SELECTOR": "EPAC-DEV"
            }
        }
    }
}
```

## Available Tools

| Tool | Description |
|------|-------------|
| `search_builtin_policies` | Search Azure built-in policy definitions by keyword |
| `create_policy_assignment` | Generate an EPAC policy assignment JSONC file |
| `create_policy_definition` | Generate a custom EPAC policy definition JSONC file |
| `list_epac_definitions` | List existing definition files in the EPAC repo |
| `build_deployment_plan` | Run `Build-DeploymentPlans` and return summary |
| `deploy_policy_plan` | Run `Deploy-PolicyPlan` to apply changes |
| `get_plan_summary` | Read and summarize the generated plan file |

## License

MIT
