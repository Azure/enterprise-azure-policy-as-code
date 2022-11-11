# Operating Environment

## EPAC Software Requirements

Your operating environment will include two repos, a runner, and at least one developer machine.

- PowerShell Core
- PowerShell Modules
    - Az
    - ImportExcel (required only if using Excel functionality)

> Note: AzCli Module, Azure CLI, and Python are no longer required as of our November 2022 release.

### Pipeline Runner Agent

OS: Any that Support PowerShell Core
Software: Must Meet EPAC Software Requirements

### Developer Workstation

- Active development vs Static deployment
    - Unlike many operations projects, this requires active development of at least yml and json, if not additional scripts
    - As the code being deployed is not static, versioning should be considered in the same manner as a software development project, rather than COTS software deployment
- Software Requirements
    - Must Meet EPAC Software Requirements
    - Must have git to retrieve github repo
- Software Recommendations
    - Visual Studio Code
