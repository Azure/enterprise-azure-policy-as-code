"""Subprocess helpers for running PowerShell 7+ and az CLI commands."""

import asyncio
import json
import shutil
from dataclasses import dataclass


@dataclass
class RunResult:
    exit_code: int
    stdout: str
    stderr: str

    @property
    def success(self) -> bool:
        return self.exit_code == 0


def _find_pwsh() -> str:
    """Locate pwsh (PowerShell 7+)."""
    pwsh = shutil.which("pwsh")
    if pwsh:
        return pwsh
    pwsh = shutil.which("pwsh.exe")
    if pwsh:
        return pwsh
    raise FileNotFoundError(
        "PowerShell 7+ (pwsh) not found on PATH. Install from https://aka.ms/powershell"
    )


async def run_pwsh(script: str, cwd: str | None = None, timeout: int = 300) -> RunResult:
    """Run a PowerShell script block and return the result."""
    pwsh = _find_pwsh()
    proc = await asyncio.create_subprocess_exec(
        pwsh, "-NoProfile", "-NonInteractive", "-Command", script,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=cwd,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        return RunResult(exit_code=-1, stdout="", stderr=f"Command timed out after {timeout}s")

    return RunResult(
        exit_code=proc.returncode or 0,
        stdout=stdout.decode("utf-8", errors="replace").strip(),
        stderr=stderr.decode("utf-8", errors="replace").strip(),
    )


async def run_az(args: list[str], timeout: int = 120) -> RunResult:
    """Run an az CLI command and return the result."""
    az = shutil.which("az") or shutil.which("az.cmd")
    if not az:
        raise FileNotFoundError("Azure CLI (az) not found on PATH.")

    proc = await asyncio.create_subprocess_exec(
        az, *args, "--output", "json",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        return RunResult(exit_code=-1, stdout="", stderr=f"az command timed out after {timeout}s")

    return RunResult(
        exit_code=proc.returncode or 0,
        stdout=stdout.decode("utf-8", errors="replace").strip(),
        stderr=stderr.decode("utf-8", errors="replace").strip(),
    )
