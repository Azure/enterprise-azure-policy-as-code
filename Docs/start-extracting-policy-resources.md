# Start by Extracting existing Policy Resources

Script `Export-AzPolicyResources` (Operations) extracts existing Policies, Policy Sets, and Policy Assignments and Exemptions outputting them in EPAC format into subfolders in folder `$outputFolders/Definitions`. The subfolders are `policyDefinitions`, `policySetDefinitions`, `policyAssignments` and `policyExemptions`.

> [!TIP]
> The script collects information on ownership of the Policy resources into a CSV file. You can analyze this file to assist in the transition to EPAC.

The scripts creates a `Definitions` folder in the `OutputFolder` with the subfolders for `policyDefinitions`, `policySetDefinitions`, `policyAssignments` and `policyExemptions`.

> [!TIP]
> In a new EPAC instance these folders can be directly copied to the `Definitions` folder enabling an initial transition from a pre-EPAC to EPAC environment.

* `policyDefinitions`, `policySetDefinitions` have a subfolder based on `metadata.category`. If the definition has no `category` `metadata` they are put in a subfolder labeled `Unknown Category`. Duplicates when including child scopes are sorted into the `Duplicates` folder. Creates one file per Policy and Policy Set.
* `policyAssignments` creates one file per unique assigned Policy or Policy Set spanning multiple Assignments.
* `policyExemptions` creates one subfolder per EPAC environment

> [!WARNING]
> The script deletes the `$outputFolders/Definitions` folder before creating a new set of files. In interactive mode it will ask for confirmation before deleting the directory.

## Use case 1: Interactive or non-interactive single tenant

`-Mode 'export'` is used to collect the Policy resources and generate the definitions file. This works for `-Interactive $true` (the default) to extract Policy resources in single tenant or multi-tenant scenario, prompting the user to logon to each new tenant in turn.

It also works for a single tenant scenario for an automated collection, assuming that the Service Principal has read permissions for every EPAC Environment in `global-settings.jsonc`.

```ps1
Export-AzPolicyResources
```

The parameter `-InputPacSelector` can be used to only extract Policy resources for one of the EPAC environments.

## Use case 2: Non-interactive multi-tenant

While this pattern can be used for interactive users too, it is most often used for multi-tenant non-interactive usage since an SPN is bound to a tenant and the script cannot prompt for new credentials.

The solution is a multi-step process:

Collect the raw information for very EPAC environment after logging into each EPAC environment (tenant):

```ps1
Connect-AzAccount -Environment $cloud -Tenant $tenantIdForDev
Export-AzPolicyResources -Interactive $false -Mode collectRawFile -InputPacSelector 'epac-dev'

Connect-AzAccount -Environment $cloud -Tenant $tenantId1
Export-AzPolicyResources -Interactive $false -Mode collectRawFile -InputPacSelector 'tenant1'

Connect-AzAccount -Environment $cloud -Tenant $tenantId2
Export-AzPolicyResources -Interactive $false -Mode collectRawFile -InputPacSelector 'tenant2'
```

Next, the collected raw files are used to generate the same output:

```ps1
Export-AzPolicyResources -Interactive $false -Mode exportFromRawFiles
```

## Caveats

The extractions are subject to the following assumptions and caveats:

* Assumes Policies and Policy Sets with the same name define the same properties independent of scope and EPAC environment.
* Ignores Assignments auto-assigned by Defender for Cloud. This behavior can be overridden with the switch parameter `-IncludeAutoAssigned`.
