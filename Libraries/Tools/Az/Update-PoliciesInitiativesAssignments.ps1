#region parameters
param (
    [Parameter(Mandatory = $true)][string]$srcRootFolder,
    [Parameter(Mandatory = $true)][bool]$whatIf,
    [Parameter(Mandatory = $true)][string] $definitionScope,

    # Parameters for Policy as Code NonProd stages 
    [Parameter(Mandatory = $true)][string] $assignmentExclutionScope,
    [parameter(Mandatory = $false)][string] $nonProdEnvDefinitionFile,
    [parameter(Mandatory = $false)][string] $nonProdAssignmentScope
)
#endregion

#region types


#region get existing Policy definitions, Initiative definitions in $definitionScope

# object contains name, list of parameters (name, type, default)

#endregion

#region get existing  Assignments in tree anchored at $definitionScope, do not process anything in the tree anchored by $assignmentExclutionScope
#endregion

#region read defined Policy definitions and Initiatiative definition from files (desired state) 
#endregion

#region read defined Assignemntss from files (desired state) 
#endregion

#region calculate list of new Policy definitions
#endregion

#region calculate list of new Initiative definitions
#endregion

#region calculate list of Policy definitions to be recreated
#endregion

#region calculate list of Policy definitions to be recreated
#endregion

#region calculate list of Policy definitions to be recreated
#endregion

#region calculate list of Policy definitions to be recreated
#endregion
