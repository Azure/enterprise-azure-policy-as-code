<#
.SYNOPSIS
    Copy pipelines and templates from starter kit to new folder

.DESCRIPTION
    This script copies pipelines and templates from the starter kit to a new folder. The script prompts for the type of pipeline to create, the branching flow to implement, and the type of script to use.

.PARAMETER StarterKitFolder
    Starter kit folder

.PARAMETER PipelinesFolder
    New pipeline folder

.PARAMETER PipelineType
    Type of DevOps pipeline to create AzureDevOps or GitHubActions?

.PARAMETER BranchingFlow
    Implementing branching flow Release or GitHub

.PARAMETER ScriptType
    Using Powershell module or script?

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Starter kit folder")]
    [string] $StarterKitFolder = "./StarterKit",

    [Parameter(Mandatory = $false, HelpMessage = "New pipeline folder")]
    [string] $PipelinesFolder = "",

    [Parameter(Mandatory = $false, HelpMessage = "Type of DevOps pipeline to create AzureDevOps or GitHubActions?")]
    [ValidateSet("AzureDevOps", "GitHubActions")]
    # [string] $PipelineType = "AzureDevOps",
    [string] $PipelineType = "GitHubActions",

    [Parameter(Mandatory = $false, HelpMessage = "Implementing branching flow Release or GitHub")]
    [ValidateSet("Release", "GitHub")]
    [string] $BranchingFlow = "Release",

    [Parameter(Mandatory = $false, HelpMessage = "Using Powershell module or script?")]
    [ValidateSet("Module", "Scripts")]
    [string] $ScriptType = "Module"
)

if (!(Test-Path $StarterKitFolder)) {
    Write-Error "Starter kit folder not found"
    return
}

$starterPipelinesFolder = ""
$starterPipelinesSubfolder = ""
$starterTemplatesSubfolder = ""
$templatesFolder = ""
$pipelineTypeText = ""
$templateTypeText = ""
switch ($PipelineType) {
    AzureDevOps {
        if ($PipelinesFolder -eq "") {
            $PipelinesFolder = "./Pipelines"
        }
        $templatesFolder = "$PipelinesFolder/templates"
        $starterPipelinesFolder = "$StarterKitFolder/Pipelines/AzureDevOps"
        $pipelineTypeText = "Azure DevOps pipelines"
        $templateTypeText = "Azure DevOps templates"
    }
    GitHubActions {
        if ($PipelinesFolder -eq "") {
            $PipelinesFolder = "./.github/workflows"
        }
        $templatesFolder = $PipelinesFolder
        $starterPipelinesFolder = "$StarterKitFolder/Pipelines/GitHubActions"
        $pipelineTypeText = "GitHub Actions workflows"
        $templateTypeText = "GitHub Actions reusable workflows"
    }
}

switch ($BranchingFlow) {
    Release {
        $starterPipelinesSubfolder = "Release-Flow"
    }
    GitHub {
        $starterPipelinesSubfolder = "GitHub-Flow"
    }
}
$starterPipelinesPath = "$starterPipelinesFolder/$starterPipelinesSubfolder/*.yml"

switch ($ScriptType) {
    Module {
        $starterTemplatesSubfolder = "templates-ps1-module"
    }
    Scripts {
        $starterTemplatesSubfolder = "templates-ps1-scripts"
    }
}
$starterTemplatesPath = "$starterPipelinesFolder/$starterTemplatesSubfolder/*.yml"

if (!(Test-Path $templatesFolder)) {
    $null = New-Item -ItemType Directory -Name $templatesFolder
}

Write-Information "Copying starter kit  $pipelineTypeText ($starterPipelinesSubfolder) from '$starterPipelinesPath' to $PipelinesFolder" -InformationAction Continue
Write-Information "Copying starter kit  $templateTypeText (use $ScriptType) from '$starterTemplatesPath' to $templatesFolder" -InformationAction Continue
Read-Host "Press Enter to continue"
Copy-Item -Path $starterPipelinesPath -Destination $PipelinesFolder
Copy-Item -Path $starterTemplatesPath -Destination $templatesFolder
