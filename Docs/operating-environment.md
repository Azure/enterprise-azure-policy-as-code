# Operating Environment

## EPAC Software Requirements

Your operating environment will include two repos, a runner, and at least one developer machine. The following software is required on the runners and any developer workstation.

* PowerShell 7.3.1 or later, 7.3.4 (latest) recommended
* PowerShell Modules
  * Az required 9.3.0 or later - **9.2.x has a bug which causes EPAC to fail**
  * ImportExcel (required only if using Excel functionality)
* Git latest version

### Pipeline Runner or Agent

OS: Any that Support PowerShell versions above.

* Linux and Windows are fully supported by EPAC
* Mac OS might work; however, we have not tested this scenario.

Software: Must Meet [EPAC Software Requirements](#epac-software-requirements).

### Developer Workstation

* Software: Must meet [EPAC Software Requirements](#epac-software-requirements).
* Software Recommendations: Visual Studio Code 1.74.3 or later (may work with older versions)

## Required Management Groups and Subscriptions

This solution requires EPAC environments for development, (optional) integration, and production per Azure tenant. These EPAC environments are not the same as the standard Azure environments for applications or solutions - do not confuse them; EPAC non-prod environment are only for development and integration of Azure Policy.  The standard Azure Sandbox, DEV, DEVINT, TEST/QA and PROD app solution environments are managed with Policy deployed from the EPAC PROD environment.

* Build a management group dedicated to Policy as Code (PaC) -- `mg-epac-dev` <br/> <https://docs.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal>
* Create management groups or subscriptions to simulate your EPAC production environments.

## Security Considerations for DevOps CI/CD Runners/Agents

Agents (also called runners) are often hosted in VMs within Azure itself. It is therefore essential to manage them as highly privileged devices.

* Utilize hardened images.
* Be managed as high-privilege assets to minimize the risk of compromise.
* Only used for a single purpose.
* Hosted in PROD tenant in multi-tenant scenarios.
* Hosted in the hub VNET or a shared services VNET.
