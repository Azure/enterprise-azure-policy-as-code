"""EPAC MCP Server — AI-driven Azure Policy management via EPAC.

Exposes EPAC PowerShell commands and Azure policy discovery as MCP tools,
enabling natural-language policy assignment creation and deployment.
"""

import json
import os
import uuid
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from .config import EpacConfig, load_config
from .runners import run_az, run_pwsh

SCHEMA_BASE = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas"

mcp = FastMCP(
    "epac",
    instructions=(
        "EPAC MCP server for Azure Policy as Code management. "
        "Use search_builtin_policies to find Azure policies, then "
        "create_policy_assignment to generate EPAC definition files, "
        "build_deployment_plan to plan, and deploy_policy_plan to apply."
    ),
)

_config: EpacConfig | None = None


def _get_config() -> EpacConfig:
    global _config
    if _config is None:
        _config = load_config()
    return _config


# ---------------------------------------------------------------------------
# Tool: search_builtin_policies
# ---------------------------------------------------------------------------
@mcp.tool()
async def search_builtin_policies(keyword: str, category: str = "") -> str:
    """Search Azure built-in policy definitions by keyword and optional category.

    Args:
        keyword: Search term to match against policy display names and descriptions.
        category: Optional category filter (e.g. "Storage", "Security", "Network").

    Returns:
        JSON array of matching policies with name, displayName, description, and policyType.
    """
    query = f"az policy definition list --query \"[?policyType=='BuiltIn' && (contains(displayName, '{keyword}') || contains(description, '{keyword}'))"
    if category:
        query += f" && properties.metadata.category=='{category}'"
    query += "].{name:name, displayName:displayName, description:description, category:metadata.category}\""

    # Use az graph query for faster results if available, fall back to az policy
    result = await run_az([
        "policy", "definition", "list",
        "--query",
        f"[?policyType=='BuiltIn' && (contains(displayName, '{keyword}') || contains(description, '{keyword}'))]"
        + (f"[?metadata.category=='{category}']" if category else "")
        + ".{name:name, displayName:displayName, description:description, category:metadata.category}",
    ])

    if not result.success:
        return json.dumps({"error": result.stderr or "Failed to search policies"})

    try:
        policies = json.loads(result.stdout)
        # Limit to top 20 for readability
        return json.dumps(policies[:20], indent=2)
    except json.JSONDecodeError:
        return json.dumps({"error": "Failed to parse policy search results", "raw": result.stdout[:500]})


# ---------------------------------------------------------------------------
# Tool: create_policy_definition
# ---------------------------------------------------------------------------
@mcp.tool()
async def create_policy_definition(
    name: str,
    display_name: str,
    description: str,
    category: str,
    policy_rule: str,
    mode: str = "All",
    parameters: str = "{}",
) -> str:
    """Create a custom EPAC policy definition JSONC file.

    Args:
        name: Unique policy name (GUID or short identifier).
        display_name: Human-readable display name.
        description: Policy description.
        category: Policy category (e.g. "Storage", "Security").
        policy_rule: JSON string of the policyRule object (the if/then block).
        mode: Policy mode — "All", "Indexed", or a resource provider mode. Default "All".
        parameters: JSON string of parameter definitions. Default "{}".

    Returns:
        Confirmation with the file path created.
    """
    cfg = _get_config()
    defs_dir = cfg.policy_definitions_dir / category
    defs_dir.mkdir(parents=True, exist_ok=True)

    try:
        rule_obj = json.loads(policy_rule)
        params_obj = json.loads(parameters)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"Invalid JSON: {e}"})

    definition = {
        "$schema": f"{SCHEMA_BASE}/policy-definition-schema.json",
        "name": name,
        "type": "Microsoft.Authorization/policyDefinitions",
        "properties": {
            "displayName": display_name,
            "policyType": "Custom",
            "mode": mode,
            "description": description,
            "metadata": {
                "version": "1.0.0",
                "category": category,
            },
            "parameters": params_obj,
            "policyRule": rule_obj,
        },
    }

    file_path = defs_dir / f"{name}.jsonc"
    with open(file_path, "w") as f:
        json.dump(definition, f, indent=4)

    return json.dumps({
        "status": "created",
        "file": str(file_path),
        "displayName": display_name,
    })


# ---------------------------------------------------------------------------
# Tool: create_policy_assignment
# ---------------------------------------------------------------------------
@mcp.tool()
async def create_policy_assignment(
    assignment_name: str,
    display_name: str,
    description: str,
    policy_name: str,
    scope: str,
    parameters: str = "{}",
    enforcement_mode: str = "Default",
    filename: str = "",
) -> str:
    """Create an EPAC policy assignment JSONC file using the EPAC tree structure.

    Args:
        assignment_name: Short name for the assignment (used in Azure resource name).
        display_name: Human-readable display name.
        description: Description of what this assignment does.
        policy_name: The policy definition name (GUID for built-in, or custom name).
        scope: Azure scope — management group, subscription, or resource group resource ID.
        parameters: JSON string of parameter values to pass to the policy. Default "{}".
        enforcement_mode: "Default" (enforce) or "DoNotEnforce" (audit only).
        filename: Optional output filename. Defaults to assignment_name.

    Returns:
        Confirmation with the file path created.
    """
    cfg = _get_config()
    assignments_dir = cfg.policy_assignments_dir
    assignments_dir.mkdir(parents=True, exist_ok=True)

    try:
        params_obj = json.loads(parameters)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"Invalid JSON in parameters: {e}"})

    # Build the EPAC assignment tree structure
    assignment = {
        "$schema": f"{SCHEMA_BASE}/policy-assignment-schema.json",
        "nodeName": f"/{assignment_name}/",
        "scope": {
            cfg.pac_selector: [scope],
        },
        "definitionEntry": {
            "policyName": policy_name,
            "displayName": display_name,
        },
        "assignment": {
            "name": assignment_name,
            "displayName": display_name,
            "description": description,
        },
        "parameters": params_obj,
    }

    if enforcement_mode != "Default":
        assignment["enforcementMode"] = enforcement_mode

    fname = filename or assignment_name
    file_path = assignments_dir / f"{fname}.jsonc"
    with open(file_path, "w") as f:
        json.dump(assignment, f, indent=4)

    return json.dumps({
        "status": "created",
        "file": str(file_path),
        "assignment_name": assignment_name,
        "policy": policy_name,
        "scope": scope,
    })


# ---------------------------------------------------------------------------
# Tool: list_epac_definitions
# ---------------------------------------------------------------------------
@mcp.tool()
async def list_epac_definitions(definition_type: str = "all") -> str:
    """List existing EPAC definition files in the definitions folder.

    Args:
        definition_type: One of "all", "policyDefinitions", "policySetDefinitions",
                         "policyAssignments", "policyExemptions". Default "all".

    Returns:
        JSON object with file listings per definition type.
    """
    cfg = _get_config()
    root = Path(cfg.definitions_root)

    types = (
        ["policyDefinitions", "policySetDefinitions", "policyAssignments", "policyExemptions"]
        if definition_type == "all"
        else [definition_type]
    )

    result = {}
    for dt in types:
        folder = root / dt
        if folder.exists():
            files = sorted(str(p.relative_to(root)) for p in folder.rglob("*.json*"))
            result[dt] = files
        else:
            result[dt] = []

    return json.dumps(result, indent=2)


# ---------------------------------------------------------------------------
# Tool: build_deployment_plan
# ---------------------------------------------------------------------------
@mcp.tool()
async def build_deployment_plan() -> str:
    """Run EPAC Build-DeploymentPlans to generate policy and role deployment plans.

    Reads the current definitions and compares with the Azure environment to
    produce policy-plan.json and roles-plan.json in the output folder.

    Returns:
        Build output summary or error details.
    """
    cfg = _get_config()
    errors = cfg.validate()
    if errors:
        return json.dumps({"error": "Invalid configuration", "details": errors})

    import_cmd = ""
    if cfg.epac_module_path:
        import_cmd = f"Import-Module '{cfg.epac_module_path}' -Force; "
    else:
        import_cmd = "Import-Module EnterprisePolicyAsCode -Force; "

    output_dir = Path(cfg.output_folder).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    script = (
        f"{import_cmd}"
        f"Build-DeploymentPlans "
        f"-PacEnvironmentSelector '{cfg.pac_selector}' "
        f"-DefinitionsRootFolder '{cfg.definitions_root}' "
        f"-OutputFolder '{output_dir}' "
    )

    result = await run_pwsh(script, timeout=600)

    if not result.success:
        return json.dumps({
            "status": "failed",
            "stderr": result.stderr[-2000:] if result.stderr else "",
            "stdout": result.stdout[-2000:] if result.stdout else "",
        })

    # Check what plan files were produced
    plan_files = list(output_dir.rglob("*-plan.json"))
    plan_names = [str(p.relative_to(output_dir)) for p in plan_files]

    return json.dumps({
        "status": "success",
        "plans_generated": plan_names,
        "output_folder": str(output_dir),
        "summary": result.stdout[-3000:] if result.stdout else "Plan completed (no output captured)",
    })


# ---------------------------------------------------------------------------
# Tool: deploy_policy_plan
# ---------------------------------------------------------------------------
@mcp.tool()
async def deploy_policy_plan() -> str:
    """Run EPAC Deploy-PolicyPlan to apply the generated policy plan to Azure.

    WARNING: This will create/update/delete Azure Policy resources according to the plan.
    Ensure you have reviewed the plan (use get_plan_summary first) before deploying.

    Returns:
        Deployment output summary or error details.
    """
    cfg = _get_config()
    errors = cfg.validate()
    if errors:
        return json.dumps({"error": "Invalid configuration", "details": errors})

    import_cmd = ""
    if cfg.epac_module_path:
        import_cmd = f"Import-Module '{cfg.epac_module_path}' -Force; "
    else:
        import_cmd = "Import-Module EnterprisePolicyAsCode -Force; "

    output_dir = Path(cfg.output_folder).resolve()
    plan_file = output_dir / "policy-plan.json"
    if not plan_file.exists():
        return json.dumps({
            "error": "No policy-plan.json found. Run build_deployment_plan first.",
            "output_folder": str(output_dir),
        })

    script = (
        f"{import_cmd}"
        f"Deploy-PolicyPlan "
        f"-PacEnvironmentSelector '{cfg.pac_selector}' "
        f"-DefinitionsRootFolder '{cfg.definitions_root}' "
        f"-InputFolder '{output_dir}' "
        f"-Interactive $false"
    )

    result = await run_pwsh(script, timeout=600)

    if not result.success:
        return json.dumps({
            "status": "failed",
            "stderr": result.stderr[-2000:] if result.stderr else "",
            "stdout": result.stdout[-2000:] if result.stdout else "",
        })

    return json.dumps({
        "status": "deployed",
        "summary": result.stdout[-3000:] if result.stdout else "Deployment completed",
    })


# ---------------------------------------------------------------------------
# Tool: get_plan_summary
# ---------------------------------------------------------------------------
@mcp.tool()
async def get_plan_summary() -> str:
    """Read and summarize the generated EPAC deployment plan.

    Returns the key changes (creates, updates, deletes) from the policy-plan.json
    so you can review before deploying.

    Returns:
        JSON summary of planned changes or error if no plan exists.
    """
    cfg = _get_config()
    output_dir = Path(cfg.output_folder).resolve()
    plan_file = output_dir / "policy-plan.json"

    if not plan_file.exists():
        return json.dumps({
            "error": "No policy-plan.json found. Run build_deployment_plan first.",
            "output_folder": str(output_dir),
        })

    with open(plan_file) as f:
        plan = json.load(f)

    # Extract summary counts from the plan
    summary = {"file": str(plan_file)}

    for resource_type in ["policyDefinitions", "policySetDefinitions", "policyAssignments", "policyExemptions"]:
        section = plan.get(resource_type, {})
        summary[resource_type] = {
            "new": len(section.get("new", [])),
            "update": len(section.get("update", [])),
            "replace": len(section.get("replace", [])),
            "delete": len(section.get("delete", [])),
            "noChange": len(section.get("noChange", section.get("unchanged", []))),
        }

    # Include first few items from new/update/delete for context
    details = {}
    for resource_type in ["policyDefinitions", "policySetDefinitions", "policyAssignments"]:
        section = plan.get(resource_type, {})
        for action in ["new", "update", "delete"]:
            items = section.get(action, [])
            if items:
                key = f"{resource_type}.{action}"
                details[key] = [
                    item.get("displayName", item.get("name", str(item)[:80]))
                    for item in items[:10]
                ]

    summary["details"] = details
    return json.dumps(summary, indent=2)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
