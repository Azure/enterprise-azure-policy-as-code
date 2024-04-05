# Hydration Kit

## Create Policy Reader Role

`New-AzPolicyReaderRole` creates a custom role EPAC Resource Policy Reader with Id `2baa1a7c-6807-46af-8b16-5e9d03fba029`. It provides read access to all Policy resources for the purpose of planning the EPAC deployments at the scope selected with PacEnvironmentSelector. The permissions granted are:

- Microsoft.Authorization/policyassignments/read
- Microsoft.Authorization/policydefinitions/read
- Microsoft.Authorization/policyexemptions/read
- Microsoft.Authorization/policysetdefinitions/read
- Microsoft.Authorization/roleAssignments/read
- Microsoft.PolicyInsights/*
- Microsoft.Management/register/action
- Microsoft.Management/managementGroups/read

## Create Azure DevOps Pipeline or GitHub Workflow

`New-PipelinesFromStarterKit` creates a new Azure DevOps Pipeline or GitHub Workflow from the starter kit. This script copies pipelines and templates from the starter kit to a new folder. The script assembles the pipelines/workflows based on the type of pipeline to create, the branching flow to implement, and the type of script to use.

`-StarterKitFolder <String>`

`-PipelinesFolder <String>`

`-PipelineType <String>` - AzureDevOps or GitHubActions; default is AzureDevOps

`-BranchingFlow <String>` - Release or GitHub (flow); default is Release

`-ScriptType <String>` - scripts (in your repo) or module (from PowerShell gallery); default is module

