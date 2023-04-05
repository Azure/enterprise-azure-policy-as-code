# PowerShell Module

!!! warning
    PowerShell module is available and is still being tested. If you encounter any issues please raise these in the GitHub project.

Enterprise Policy as Code is now available as a PowerShell module. To install follow the instructions below.

```
Install-Module EnterprisePolicyAsCode
Import-Module EnterprisePolicyAsCode
```

## Known Issues

- ```Build-DeploymentPlans``` - use the -outputFolder parameter otherwise it will create an Output folder in the module folder
- ```Deploy-RolesPlan``` - use the -inputFolder parameter and specify the folder in the previous step
- ```Deploy-PolicyPlan``` - use the -inputFolder parameter and specify the folder in the previous step
- ```Build-DefinitionsFolder``` - currently not supported - replacement due in April 2023
