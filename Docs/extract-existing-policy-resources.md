# Extract existing Policy Resources from an Environment in EPAC Format

Script `Export-AzPolicyResources.ps1` (Operations) extracts existing Policies, Policy Sets, and Policy Assignments and Exemptions outputing them in EPAC format into subfolders in folder `$outputFolders/Definitions`. The subfolders are `policyDefinitions`, `policySetDefinitions`, `policyAssignments` and `policyExemptions`. In a new EPAC instance these subfolders can be directly copied to the `Definitions` folder enabling an initial transition from a pre-EPAC to EPAC environment.

The scripts creates a `Definitions` folder in the `outputFolder` and subfolders for `policyDefinitions`, `policySetDefinitions` and `policyAssignments`. To use the generated files copy them to your `Definitions` folder.

* `policyDefinitions`, `policySetDefinitions` have a subfolder based on `metadata.category`. If the definition has no `category` `metadata` they are put in a subfolder labeled `Unknown Category`. Duplicates when including child scopes are sorted into the `Duplicates` folder. Creates one file per Policy and Policy Set.
* `policyAssignments` creates one file per unique assigned Policy or Policy Set spanning multiple Assignments.
* `policyExemptions` creates one subfolder per EPAC environment

The script works for two principal use cases indicated by three modes:

## Use case 1: Interactive or non-interactive single tenant

`-Mode 'export'` is used to collect the Policy resources and generate the definitions file. This works for `-Interactive $true` (the default) to extract Policy resources in single tenant or multi-tenant scenario, prompting the user to logon to each new tenant in turn.

It also works for a single tenant scenario for an automated collection, assuming that the Service Principal has read permissions for every EPAC Environment in `global-settings.jsonc`.

```ps1
Export-AzPolicyResources
```

The parameter `-InputPacSelector` can be used to only extract Policy resources for one of the EPAC environments.

!!! warning
    The script deletes the `$outputFolders/Definitions` folder before creating a new set of files. In interactive mode it will ask for confirmation before deleting the directory.

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

!!! warning
    This last script deletes the `$outputFolders/Definitions` folder before creating a new set of files.

## Caveats

The extractions are subject to the following assumptions and caveats:

* Assumes Policies and Policy Sets with the same name define the same properties independent of scope and EPAC environment.
* Ignores Assignments auto-assigned by Defender for Cloud. This behavior can be overridden with the switch parameter `-IncludeAutoAssigned`.

## Script parameters

|Parameter | Explanation |
|----------|-------------|
| `DefinitionsRootFolder` | Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER` or `./Definitions`. It contains `global-settings.jsonc`.
| `OutputFolder` | Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER` or `./Outputs`.
| `Interactive` | Script is being run interactively and can request az login. It will also prompt for each file to process or skip. Defaults to $true. |
| `IncludeChildScopes` | Switch parameter to include Policies and Policy Sets in child scopes; child scopes are normally ignored for definitions. This does not impact Policy Assignments. |
| `IncludeAutoAssigned` | Switch parameter to include Assignments auto-assigned by Defender for Cloud. |
| `ExemptionFiles` | Create Exemption files (none=suppress, csv=as a csv file, json=as a json or jsonc file). Defaults to 'csv'. |
| `FileExtension` | Controls the output files extension. Default is `jsonc` but `json` is also accepted |
| `Mode` | a) `export` exports EPAC environments, must be used with -Interactive in a multi-tenant scenario<br/> b) `collectRawFile` exports the raw data only; used with `InputPacSelector` when running non-Interactive in a multi-tenant scenario to collect the raw data once per tenant <br/> c) `exportFromRawFiles` reads the files generated with one or more runs of b) and outputs the files like the normal 'export' without re-reading the environment. |
| `InputPacSelector` | Limits the collection to one EPAC environment, useful for non-Interactive use in a multi-tenant scenario, especially with -Mode 'collectRawFile'. Default is `'*'` which will execute all EPAC environments. This can be used in other scenarios.|
