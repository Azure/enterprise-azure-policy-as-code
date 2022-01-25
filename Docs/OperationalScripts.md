# Operational Scripts

Opaerational scripts can be used to manage operational aspects of Policy as Code.

## CreateAzRemediationTasks.ps1

This script executes all remediation tasks in a Policy as Code environment specified with parameter **environmentSelector**. The script will interactively prompt for the value if the parameter is not supplied. The definition of the Management Groups and Subscriptions which define an environment are in /Scripts/Config/Get-AzEnvironmentDefinitions.ps1. The script will recurse the Management Group structure and subscriptions from the defined point

* Find all Policy assignments with potential remediations
* Query Policy Insights for non-complaint resources
* Start remediation task for each Policy with non-compliant resources

The script has two switch parameters controlling the verbosity of the output

* **suppressCollectionInformation** controls  the script listing all the collection steps about Management Groups, Subscriptions, Policy Assignments and non-compliance summaries.
* **suppressCreateInformation** controls the script listing the remediation tasks created.

## Get-AzPolicyActiveEffects.ps1

Creates a list with the effective Policy effects for the security baseline assignments per environment (DEV, DEVINT, NONPROD, PROD, etc.). The script needs the representative assignments defined for each environment in **<nobr>Get-RepresentativeAssignmnets.ps1</nobr>**. This list must be converted into a usable file by pipeing the output through ConvertTo-Csv and pipe the output to a file:

``.\Scripts\Operations\Get-AzPolicyActiveEffects.ps1 -InformationAction Continue | ` `` <br>``ConvertTo-Csv | Out-File .\Output\effective-effects.csv``

## Miscelaneous Scripts

The remining scripts in the folder /Scripts/OpaerationScripts do not require configuration and name describes their function. Many require the tenant ID and the name of the output file

* **Get-AzResourceTags.ps1** - lists all resource tgas
* **Get-AzMissingTags.ps1** - lists missing tags based on non-compliant resource groups
* **Get-AzStorageNetworkConfig.ps1** - lists Storage Account network configurations
* **Get-AzUserRoleAssignments.ps1** - List role assignments

- **[Definitions](Definitions.md)**
- **[Pipeline](Pipeline.md)**
- **[Scripts and Configuration Files](ScriptsAndConfigurationFiles.md)**
- **[Quick Start guide](../README.md)**
- **[Assignments](Assignments.md)**

[Return to the main page.](../README.md)
