"""Configuration loader for EPAC MCP server."""

import json
import os
from dataclasses import dataclass, field
from pathlib import Path

CONFIG_FILENAME = "config.json"


@dataclass
class EpacConfig:
    definitions_root: str = ""
    pac_selector: str = ""
    output_folder: str = "./Output"
    epac_module_path: str | None = None

    @property
    def policy_definitions_dir(self) -> Path:
        return Path(self.definitions_root) / "policyDefinitions"

    @property
    def policy_assignments_dir(self) -> Path:
        return Path(self.definitions_root) / "policyAssignments"

    @property
    def policy_exemptions_dir(self) -> Path:
        return Path(self.definitions_root) / "policyExemptions"

    @property
    def policy_set_definitions_dir(self) -> Path:
        return Path(self.definitions_root) / "policySetDefinitions"

    def validate(self) -> list[str]:
        errors = []
        if not self.definitions_root:
            errors.append("definitions_root is required")
        elif not Path(self.definitions_root).exists():
            errors.append(f"definitions_root does not exist: {self.definitions_root}")
        if not self.pac_selector:
            errors.append("pac_selector is required")
        return errors


def load_config() -> EpacConfig:
    """Load config from config.json next to the server, env vars, or defaults."""
    config = EpacConfig()

    # Try loading from config.json in the server directory
    server_dir = Path(__file__).parent.parent
    config_path = server_dir / CONFIG_FILENAME
    if config_path.exists():
        with open(config_path) as f:
            data = json.load(f)
        config.definitions_root = data.get("definitions_root", "")
        config.pac_selector = data.get("pac_selector", "")
        config.output_folder = data.get("output_folder", "./Output")
        config.epac_module_path = data.get("epac_module_path")

    # Env vars override file config
    config.definitions_root = os.environ.get(
        "EPAC_DEFINITIONS_ROOT", config.definitions_root
    )
    config.pac_selector = os.environ.get("EPAC_PAC_SELECTOR", config.pac_selector)
    config.output_folder = os.environ.get("EPAC_OUTPUT_FOLDER", config.output_folder)
    config.epac_module_path = os.environ.get(
        "EPAC_MODULE_PATH", config.epac_module_path
    )

    return config
