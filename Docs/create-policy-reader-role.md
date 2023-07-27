# Create Policy Reader Role

Creates a custom role `EPAC Resource Policy Reader` with `Id` `2baa1a7c-6807-46af-8b16-5e9d03fba029`. It provides read access to all Policy resources for the purpose of planning the EPAC deployments at the scope selected with `PacEnvironmentSelector`. The permissions granted are:

* `Microsoft.Authorization/policyassignments/read`
* `Microsoft.Authorization/policydefinitions/read`
* `Microsoft.Authorization/policyexemptions/read`
* `Microsoft.Authorization/policysetdefinitions/read`
* `Microsoft.PolicyInsights/*`
* `Microsoft.Management/register/action`
* `Microsoft.Management/managementGroups/read`

<!-- insert paramters as a table -->
## Script Parameters

| Parameter | Description |
| --- | --- |
| `PacEnvironmentSelector` | Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc`. |
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'`. It contains `global-settings.jsonc`. |
| `Interactive` | Script is being run interactively and can request az login. Defaults to $false if PacEnvironmentSelector parameter provided and $true otherwise. |

## Examples

```ps1
.\New-AzPolicyReaderRole.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -Interactive $true
```

```ps1
.\New-AzPolicyReaderRole.ps1 -Interactive $true
```

```ps1
.\New-AzPolicyReaderRole.ps1 -Interactive $true -DefinitionsRootFolder "C:\Src\Definitions"
```

```ps1
.\New-AzPolicyReaderRole.ps1 -Interactive $true -DefinitionsRootFolder "C:\Src\Definitions" -PacEnvironmentSelector "dev"
```
