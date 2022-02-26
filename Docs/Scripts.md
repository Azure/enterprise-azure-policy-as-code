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

## Policy and Initiative definition configuration scripts

The `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` analyzes changes in policy, initiative, and assignment files. The  `Deploy-AzPoliciesInitiativesAssignmentsFromPlan.ps1` script is used to deploy policies, initiatives, and assignments at their desired scope, the `Remove-AzPoliciesIdentitiesRoles.ps1` file is used to remove unnecessary roles and identities given out previously, and the `Plan File.json` is an artifact created by the pipeline run that is used to show the expected changes in Azure.

![image.png](https://github.com/Azure/enterprise-azure-policy-as-code/blob/main/Docs/Images/FileProcessing.PNG)
The deployment scripts are **declarative** and **idempotent**: this means, that regardless how many times they are run, they always push all changes that were implemented in the JSON files to the Azure environment, i.e. if a JSON file is newly created/updated/deleted, the pipeline will create/update/delete the Policy and/or Initiative definition in Azure. If there are no changes, the pipeline can be run any number of times, as it won't make any changes to Azure.

## Next steps

**[Policy and Initiative Definitions](Definitions.md)** <br/>
**[Policy Assignments](Assignments.md)** <br/>
**[Pipeline Details](Pipeline.md)** <br/>
**[Return to the main page](../README.md)** <br/>
<a href="#top">Back to top</a>

