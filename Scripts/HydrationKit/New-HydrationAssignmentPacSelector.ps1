<#
.SYNOPSIS
    This function creates a new PAC selector block in an EPAC assignment configuration file based on a source PAC selector assignment.

.DESCRIPTION
    The New-HydrationAssignmentPacSelector function is used to create a new EPAC assignment PAC selector. 
    It takes as input the source PAC selector, the new PAC selector, and optionally the definitions, output, 
    management group hierarchy prefix, and management group hierarchy suffix. It then processes JSON and JSONC files 
    in the specified definitions directory, creating new directories and files as needed.

.PARAMETER SourcePacSelector
    The source PAC selector. The scope will be duplicated in the NewPacSelector scope block. This parameter is mandatory.

.PARAMETER NewPacSelector
    The NewPacSelector to be created. This should already exist in your global-settings.ini file. This parameter is mandatory.

.PARAMETER Definitions
    The directory containing the definitions for your EPAC repo. Defaults to "./Definitions".

.PARAMETER Output
    The directory where the output will be stored for review prior to import into your EPAC repo. Defaults to "./Output".

.PARAMETER MGHierarchyPrefix
    The prefix for the management group hierarchy. This is commonly used when copying to a PacSelector within the existing tenant to avoid naming collisions, such as when setting up the EPAC-Dev DevOps Pipeline Testing deployment hierarchy. This parameter is optional.

.PARAMETER MGHierarchySuffix
    The suffix for the management group hierarchy. This is commonly used when copying to a PacSelector within the existing tenant to avoid naming collisions, such as when setting up the EPAC-Dev DevOps Pipeline Testing deployment hierarchy. This parameter is optional.

.EXAMPLE
    New-HydrationAssignmentPacSelector -SourcePacSelector "Prod" -NewPacSelector "EpacDev" -MGHierarchyPrefix "epac-"

    This will create a new PAC selector named "EpacDev" based on the "Prod" PacSelector in your global-settings.ini file.

.NOTES
    Assignments to Subscriptions and Resource Group Scopes will not be duplicated, as these cannot be valid in the new environment due to SubscriptionId GUID uniqueness requirements.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function New-HydrationAssignmentPacSelector {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "The source PAC selector. The scope will be duplicated in the NewPacSelector scope block. This parameter is mandatory.")]
        [string]
        $SourcePacSelector,
        [Parameter(Mandatory = $true, HelpMessage = "The NewPacSelector to be created. This should already exist in your global-settings.ini file. This parameter is mandatory.")]
        [string]
        $NewPacSelector,
        [Parameter(Mandatory = $false, HelpMessage = "The directory containing the definitions for your EPAC repo. Defaults to './Definitions'.")]
        [string]
        $Definitions = "./Definitions",
        [Parameter(Mandatory = $false, HelpMessage = "The directory where the output will be stored for review prior to import into your EPAC repo. Defaults to './Output'.")]
        [string]
        $Output = "./Output",
        [Parameter(Mandatory = $false, HelpMessage = "The prefix for the management group hierarchy. This is commonly used when copying to a PacSelector within the existing tenant to avoid naming collisions, such as when setting up the EPAC-Dev DevOps Pipeline Testing deployment hierarchy. This parameter is optional.")]
        [string]
        $MGHierarchyPrefix,
        [Parameter(Mandatory = $false, HelpMessage = "The suffix for the management group hierarchy. This is commonly used when copying to a PacSelector within the existing tenant to avoid naming collisions, such as when setting up the EPAC-Dev DevOps Pipeline Testing deployment hierarchy. This parameter is optional.")]
        [string]
        $MGHierarchySuffix
    )
    $sourcePath = Join-Path $Definitions "policyAssignments"
    $InformationPreference = "Continue"
    foreach ($s in @($sourcePath, $Definitions)) {
        if (!(Test-Path -Path $s)) {
            Write-Error "Path $s does not exist."
            return
        }
    }
    if (!(Test-Path -Path $Output)) {
        Write-Information "Creating directory $Output..."
        $null = New-Item -Path $Output -ItemType Directory -Force
    }
        
    $fileList = Get-ChildItem -Path $sourcePath -Recurse -File -Include "*.json", "*.jsonc"
    $regex = "(policyAssignments.*)"
    foreach ($f in $fileList) {
        $relativePath = (($f.FullName | Select-String -Pattern "(?<=${regex}).*").matches[0].value).Replace('\', '/')
        $outputFile = Join-Path $Output "UpdatedAssignments" $relativePath
        $outputParent = Split-Path $outputFile -Parent
        Write-Debug "    relativePath: $relativePath"
        Write-Debug "    outputFile: $outputFile"
        Write-Debug "    NewPacSelector: $newPacSelector"
        Write-Debug "    NewPacSelector Exists: $($json.scope.($NewPacSelector))"
        $json = Get-Content -Path $f.FullName -Raw | ConvertFrom-Json -Depth 10
        if ($json.scope.($NewPacSelector)) {
            if ($DebugPreference -eq "Continue") {
                $json.scope.($NewPacSelector) | convertto-json -depth 10
            }
            Write-Warning "    Scope $($NewPacSelector) already exists in $($f.FullName), copying file in current state..."
            if (!(Test-Path -Path $outputParent)) {
                Write-Debug "    Creating directory $outputParent..."
                $null = New-Item -Path  $outputParent -ItemType Directory -Force
            }
            $json | ConvertTo-Json -Depth 100 | Set-Content -Path $outputFile
            continue
        }
        else {
            $scopeList = $json.scope.($SourcePacSelector)
            if ($json.children) {
                $i = 0
                foreach ($c in $json.children) {
                    $c.scope
                    if ($c.scope.($NewPacSelector)) {
                        $i++
                    }
                }
            }
            if (!($scopeList -and !($i -gt 0))) {
                Write-Debug "    No scope found for $SourcePacSelector in $($f.FullName), reviewing children..."
                foreach ($c in $json.children) {
                    Write-Debug "    Processing child $($c.nodeName)..."
                    $c.scope.($SourcePacSelector)
                    if ($c.scope.($SourcePacSelector)) {
                        $childScope = @()
                        foreach ($scope in $($c.scope.($SourcePacSelector))) {
                            if ($scope -like "/subscriptions/*") {
                                Write-Warning "$($json.assignment.name): $($json.assignment.displayName) is assigned to subscription $scope, this cannot be duplicated without a specific subscription in the environment $NewPacSelector"
                            }
                            else {
                                $childScope += "/providers/Microsoft.Management/managementGroups/" + $MGHierarchyPrefix + $(Split-Path $scope -Leaf) + $MGHierarchySuffix
                                Write-Debug "    Added Child Scope: $($childScope[-1])"
                                Write-Debug "    New Scope Name: $($c.nodeName)"
                            }
                        }
                        $c.scope | Add-Member -MemberType NoteProperty -Name $NewPacSelector -Value $childScope
                    }
                    else {
                        Write-Debug "    No scope found for $($SourcePacSelector) in $($c.nodeName), skipping..."
                        # $c.scope
                    }
                }
            }
            elseif ($i -gt 0) {
                Write-Warning "    Scope $($NewPacSelector) already exists in $($f.FullName), copying file in current state..."
            }
            else {
                $newScope = @()
                foreach ($scope in $scopeList) {
                    if ($scope -like "/subscriptions/*") {
                        Write-Warning "$($c.assignment.name): $($c.assignment.displayName) is assigned to subscription $scope, this cannot be duplicated without a specific subscription in the environment $NewPacSelector"
                    }
                    else {
                        $newScope += "/providers/Microsoft.Management/managementGroups/" + $MGHierarchyPrefix + $(Split-Path $scope -Leaf) + $MGHierarchySuffix
                        $json.scope | Add-Member -MemberType NoteProperty -Name $NewPacSelector -Value $newScope
                    }
                            
                }
            }
            if ($json.scope.$($NewPacSelector) -or $json.children.scope.$($NewPacSelector)) {
                Write-Debug "    New Scope Name: $NewPacSelector"
                Write-Debug "    Updated Scope: $(($json.scope.$($NewPacSelector)) -join ",")"
            }
            else {
                Write-Warning "No scope found for $($NewPacSelector) in $($f.FullName), skipping..."
                continue
            }
            if (!(Test-Path -Path $outputParent)) {
                Write-Information "Creating directory $outputParent..."
                $null = New-Item -Path  $outputParent -ItemType Directory -Force
            }
            $json | ConvertTo-Json -Depth 100 | Set-Content -Path $outputFile
        }
    }
}