# Debugging EPAC

This is the process used to debug EPAC scripts during troubleshooting that the maintainers follow. You can use this in your own environment to help with finding faults.

## Environment Setup

- Clone the repository locally, you can debug the PowerShell module and make changes to it but occasionally that folder is locked down
- Use Visual Studio Code to help step through the debugging process
- Create a `script.ps1` file in the root of your project. In that file put the command you are trying to run - referencing the scripts from the downloaded repository files e.g.

```
# The cloned repository is in the epac-github folder
..\epac-github\Scripts\Deploy\Build-DeploymentPlans.ps1 -DefinitionsRootFolder .\Definitions -OutputFolder Output
```

- In Visual Studio Code add a breakpoint to the script above - so when you hit F5 to start debugging the script will break there.
- Step into the main script you are debugging.
- Use the normal debugging process in Visual Studio Code to reach the section of the script you believe is causing the error. Insert breakpoints as required to skip larger portions of code that are irrelevant to the issue you are facing.
- As you make changes to code restart the debug process to test if changes were successful.

Use the dependency map below for a high level view of `Build-DeploymentPlans.ps1`

```
Build-DeploymentPlans.ps1
├── Initialization & Configuration
│   ├── Add-HelperScripts.ps1 (loads all helper functions)
│   ├── Select-PacEnvironment (determines PAC environment)
│   └── Set-AzCloudTenantSubscription (Azure authentication)
│
├── Azure Resource Discovery
│   ├── Build-ScopeTableForDeploymentRootScope (scope hierarchy)
│   └── Get-AzPolicyResources (retrieves deployed resources)
│       └── Returns: Policy/PolicySet definitions, Assignments, Exemptions, Role 
│
├── Plan Building (Conditional based on folder presence)
│   ├── Build-PolicyPlan (Policy Definitions)
│   ├── Build-PolicySetPlan (Policy Set Definitions)
│   ├── Build-AssignmentPlan (Policy Assignments + Role Assignments)
│   └── Build-ExemptionsPlan (Policy Exemptions)
│
├── Supporting Functions
│   ├── Get-PolicyResourceProperties (extract resource properties)
│   └── Convert-PolicyResourcesToDetails (convert to detailed info)
│
└── Output & Reporting
    ├── Write-ModernHeader (visual headers)
    ├── Write-ModernSection (section headers)
    ├── Write-ModernStatus (status messages)
    ├── Write-ModernCountSummary (change summaries)
    └── Submit-EPACTelemetry (telemetry, optional)
```