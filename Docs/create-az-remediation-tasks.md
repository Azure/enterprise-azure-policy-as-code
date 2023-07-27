# Batch Creation of Remediation Tasks

The script `Create-AzRemediationTasks.ps1` creates remediation tasks for all non-compliant resources for EPAC environments in the `global-settings.jsonc` file.

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The script will recurse the Management Group structure and subscriptions from the defined starting point.

* Find all Policy assignments with potential remediation capable resources
* Query Policy Insights for non-complaint resources
* Start remediation task for each Policy with non-compliant resources

## Script Parameters

| Parameter | Description |
| --- | --- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'`. |
| `Interactive` | Set to false if used non-interactive |
| `OnlyCheckManagedAssignments` | Include non-compliance data only for Policy assignments owned by this Policy as Code repo |
| `PolicyDefinitionFilter` | Filter by Policy definition names (array) or ids (array). |
| `PolicySetDefinitionFilter` | Filter by Policy Set definition names (array) or ids (array). |
| `PolicyAssignmentFilter` | Filter by Policy Assignment names (array) or ids (array). |
| `PolicyEffectFilter` | Filter by Policy effect (array). |


## Examples

```ps1
Create-AzRemediationTasks -PacEnvironmentSelector "dev"
```

```ps1
Create-AzRemediationTasks -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions"
```

```ps1
Create-AzRemediationTasks -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -Interactive $false
```

```ps1
Create-AzRemediationTasks -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -OnlyCheckManagedAssignments
```

```ps1
Create-AzRemediationTasks -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -PolicyDefinitionFilter "Require tag 'Owner' on resource groups" -PolicySetDefinitionFilter "Require tag 'Owner' on resource groups" -PolicyAssignmentFilter "Require tag 'Owner' on resource groups"
```

## Links

- [Remediate non-compliant resources with Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal)
- [Start-AzPolicyRemediation](https://learn.microsoft.com/en-us/powershell/module/az.policyinsights/start-azpolicyremediation?view=azps-10.1.0)
