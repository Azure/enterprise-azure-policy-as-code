<#
    .SYNOPSIS
        Retrieves the definition subfolder for a given content ID by searching through a policySetDefinition or policyAssignment. This is intended to be used in conjunction with Move-PolicyByAssignment as a parent script.

    .DESCRIPTION
        The Get-HydrationDefinitionSubfolderByContentId function retrieves the definition subfolder associated with a specific content ID. 
        If found in a policySetDefinition, the function will check whether or not the assignment for that was located earlier in the parent script, which is defined in $CategoryList. If this assignment is found, then the assignment subfolder will be returned for that policySetDefinition's Assignment.
        If found in a policyAssignment, the function will return the subfolder of the assignment.
        If found in both, the higher security option will be taken.
        If found in neither, the function will return "NotFound" so that it can be placed in the designated location for unused definitions.

    .PARAMETER ContentId
        The ID of the policyAssignment or policy for which to retrieve the definition subfolder.

    .EXAMPLE
        Get-HydrationDefinitionSubfolderByContentId -ContentId "myPolicy" -ContainerDefinitionPath "C:\path\to\policyAssignments\myAssignment.json" -CategoryList $CategoryList

        This command retrieves the definition subfolder for the content with ID "12345".

    .LINK
        https://aka.ms/epac
        https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md

    #>
function Get-HydrationDefinitionSubfolderByContentId {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ContentId,
        [Parameter(Mandatory = $true)]
        [string]
        $ContainerDefinitionPath,
        [System.Management.Automation.OrderedHashtable]
        $CategoryList
    )
    if ($(Resolve-Path $ContainerDefinitionPath) -like "*policyAssignments*") {
        $intAssignmentPath = $ContainerDefinitionPath
        $fileType = "policyAssignments"
    }
    elseif ($(Resolve-Path $ContainerDefinitionPath) -like "*policySetDefinitions*") {
        $intPolicySetPath = $ContainerDefinitionPath
        $fileType = "policySetDefinitions"
    }
    Write-Debug $ContainerDefinitionPath
    Write-Debug "    fileType: $fileType"
    if ($intAssignmentPath) {
        Write-Debug "    Testing intAssignmentPath $intAssignmentPath for $ContentId..."
        $intAssignmentPath = Resolve-Path $intAssignmentPath
        $assignment = Get-Content -Path $intAssignmentPath | ConvertFrom-Json -Depth 100
        $relativePath = $intAssignmentPath -replace ".*policyAssignments[/\\]"
        Write-Debug "    relativePath: $relativePath"
        Write-Debug "    assignment.definitionEntryList: $($assignment.definitionEntryList)"
        Write-Debug "    assignment.definitionEntry: $($assignment.definitionEntry)"
        if ($assignment.definitionEntryList) {
            Write-Debug "    Testing $($assignment.definitionEntry.count) assigned definitions for $ContentId..."
            ForEach ($a in $assignment.definitionEntryList) {
                # policyId and policySetId are not necessary as they refer to built-in objects that are not managed within the stored hierarchy
                if ($a.policySetName -contains $ContentId -or $a.policyName -contains $ContentId) {
                    Write-Debug "Found $ContentId in $relativePath..."
                    $subfolder = ($relativePath -split '[/\\]')[0]
                    Write-Debug "Found $ContentId in $relativePath, will send to $subfolder..."
                    return $subfolder
                }
                else {
                    write-Debug "$ContentId not found in $intAssignmentPath"
                    return "NotFound"
                }
            }
        }
        elseif ($assignment.definitionEntry) {
            # policyId and policySetId are not necessary as they refer to built-in objects that are not managed within the stored hierarchy
            if ($assignment.definitionEntry.policySetName -eq $ContentId -or $assignment.definitionEntry.policyName -eq $ContentId) {
                Write-Debug "Found $ContentId in $relativePath..."
                $subfolder = ($relativePath -split '[/\\]')[0]
                return $subfolder
            }
            else {
                write-Debug "$ContentId not found in $intAssignmentPath"
                return "NotFound"
            }
        }
        else {
            write-Debug "$ContentId not found in $intAssignmentPath"
            return "NotFound"
        }
    }
    if ($intPolicySetPath) {
        if (!($CategoryList)) {
            Write-Error "CategoryList is required to process policySetDefinitions to the same location as the parent."
            return
        }
        if ($policySet.properties.policyDefinitions) {
            Write-Debug "    $($policySet.Name) policyDefinitions.count: $($policySet.properties.policyDefinitions.count)"
            if ($policySet.properties.policyDefinitions.policyDefinitionName -contains $ContentId) {
                Write-Debug "    Found $ContentId in $intPolicySetPath, checking assignment..."
                
                # Search through CategoryList for policySetPath here
                # If not found, throw error, this should have been categorized already in Move-PolicyByAssignment as policySets are processed first.
                $policySetAssignment = ($CategoryList | Where-Object { $_.Value.SourceFile -eq $intPolicySetPath }).NewFilePath
                Write-Debug "policySetAssignment.AssignmentFile: $($policySetAssignment.AssignmentFile)"
                if ($DebugPreference -eq "Continue") { $policySetAssignment }
                if ($policySetAssignment) {
                    $subfolder = (($policySetAssignment.AssignmentFile -replace ".*policyAssignments[/\\]") -split '[/\\]')[0]
                    return $subfolder
                }
                else {
                    Write-Error "The referenced policySet is not in the categorized list, this should not happen."
                }
                return $subfolder
            }
        }
        else {
            return "NotFound"
        }
    }
}