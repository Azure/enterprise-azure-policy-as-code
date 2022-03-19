# Scripts

**Note** Many scripts use a parameter or a configuration value called `RootScope`. It denotes the location of the custom Policy or Initiative definitions. If this parameter/setting does not follow this rule, the scripts will break.

## Deployment Scripts

Deployment scripts are documented with the [pipeline documentation](../Pipeline/README.md)

## Operational Scripts

### **Script:** New-AzPolicyReaderRole.ps1

Creates a custom role `Policy Contributor` at the scope selected with `PacEnvironmentSelector`:

- `Microsoft.Authorization/policyAssignments/read`
- `Microsoft.Authorization/policyDefinitions/read`
- `Microsoft.Authorization/policySetDefinitions/read`

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Required | Selects the assignable scope using rootScope. If omitted, interactively prompts for the value. |
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |

<br/>[Back to top](#scripts)<br/>

### **Script:** CreateAzRemediationTasks.ps1

This script executes all remediation tasks in a Policy as Code environment specified with parameter `PacEnvironmentSelector`. The script will interactively prompt for the value if the parameter is not supplied. The definition of the Management Groups and Subscriptions which define an environment are in [./Scripts/Config/Get-AzEnvironmentDefinitions.ps](#get-azenvironmentdefinitions_ps1). The script will recurse the Management Group structure and subscriptions from the defined starting point.

* Find all Policy assignments with potential remediations
* Query Policy Insights for non-complaint resources
* Start remediation task for each Policy with non-compliant resources

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Required | Selects the tenant, rootScope, defaultSubscription, assignment scopes/notScope and file names. If omitted, interactively prompts for the value. |
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |

<br/>[Back to top](#scripts)<br/>

### **Script:** Get-AzEffectsForEnvironments.ps1

Creates a list with the effective Policy effects for the security baseline assignments per environment (DEV, DEVINT, NONPROD, PROD, etc.). The script needs the representative assignments defined for each environment in [`./Definitions/global-settings.jsonc`](#Get-RepresentativeAssignmnets_ps1).

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `outputPath` | Optional | Folder for the output file. Default: `./Output/AzEffects/Environments/`. |
| `outputType` | Optional | Specifies the output format <br/> `csv` is the default and creates an Excel CSV file. <br/> `json` creates the same output as a JSON file. <br/> `pipeline` pipes the output into the PowerShell pipeline. |
| `PacEnvironmentSelector` | Required | Selects the tenant, rootScope, defaultsubscription, assignment scopes and file names. If omitted, interactively prompts for the value.|
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |

<br/>[Back to top](#scripts)<br/>

### **Script:** Get-AzEffectsForInitiatives.ps1

Script calculates the effect parameters for the specified Initiative(s) outputing:

* Comparison table (csv) to see the differences between 2 or more initaitives (most useful for compliance Initiatives)
* List (csv) of default effects for a single initiative
* Json snippet with parameters for each initiative

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `initiativeSetSelector` | Optional | Specifies the initaitive set to compare from GlobalSettings. If omitted, interactively prompts for the value. |
| `outputPath` | Optional | Folder for the output files. Default: `./Output/AzEffects/Initiatives/`. |
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |

<br/>[Back to top](#scripts)<br/>

### **Script:** Get-AzResourceTags.ps1

Lists all resource tags in tenant.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Required | Selects the tenant, rootScope, defaultsubscription, assignment scopes and file names. If omitted, interactively prompts for the value.|
| `OutputFileName` | Optional | Output file name. |
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |

<br/>[Back to top](#scripts)<br/>

### **Script:** Get-AzMissingTags.ps1

Lists missing tags based on non-compliant Resource Groups.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Required | Selects the tenant, rootScope, defaultsubscription, assignment scopes and file names. If omitted, interactively prompts for the value.|
| `OutputFileName` | Optional | Output file name. |
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |

<br/>[Back to top](#scripts)<br/>

### **Script:** Get-AzStorageNetworkConfig.ps1

Lists Storage Account network configurations.

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `PacEnvironmentSelector` | Required | Selects the tenant, rootScope, defaultsubscription, assignment scopes and file names. If omitted, interactively prompts for the value.|
| `OutputFileName` | Optional | Output file name. |
| `GlobalSettingsFile` | Optional | Global settings file path. Default: `./Definitions/global-settings.jsonc`. |

<br/>[Back to top](#scripts)<br/>

## Test Scripts

The test scripts are used to exercise deployment and helper scripts for debugging purposes. They simply invoke those scripts with the parameters set based on the optional `PacEnvironmentSelector` parameter as defined in [./Scripts/Config/Get-AzEnvironmentDefinitions.ps](#get-azenvironmentdefinitions_ps1). The parameter is positional. If omitted, the script will interactively prompt for a value.

* Test-GetAzAssignments.ps1
* Test-BuildAzPoliciesInitiativesAssignmentsPlan.ps1
* Test-DeployAzPoliciesInitiativesAssignmentsFromPlan.ps1
* Test-SetAzPolicyRolesFromPlan.ps1

<br/>[Back to top](#scripts)<br/>

## Reading List

1. **[Pipeline](../Pipeline/README.md)**

1. **[Update Global Settings](../Definitions/README.md)**

1. **[Create Policy Definitions](../Definitions/Policies/README.md)**

1. **[Create Initiative Definitions](../Definitions/Initiatives/README.md)**

1. **[Define Policy Assignments](../Definitions/Assignments/README.md)**

1. **[Scripts](#Scripts)**

**[Return to the main page](../README.md)**
<br/>[Back to top](#scripts)<br/>
