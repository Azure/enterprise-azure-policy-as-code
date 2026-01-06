function Export-PolicyDiffArtifact {
    <#
    .SYNOPSIS
    Exports detailed diff information to a JSON file for tooling integration.
    
    .DESCRIPTION
    Generates a policy-diff.json artifact containing all changes detected during plan building.
    Useful for CI/CD pipelines, automated testing, and integration with external tools.
    
    .PARAMETER PolicyPlan
    The policy deployment plan containing diff information
    
    .PARAMETER RolesPlan
    The roles deployment plan containing diff information
    
    .PARAMETER OutputFolder
    The folder where the diff artifact should be written
    
    .EXAMPLE
    Export-PolicyDiffArtifact -PolicyPlan $policyPlan -RolesPlan $rolesPlan -OutputFolder "Output/plans-dev"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable] $PolicyPlan,
        
        [Parameter(Mandatory = $false)]
        [hashtable] $RolesPlan,
        
        [Parameter(Mandatory = $true)]
        [string] $OutputFolder
    )
    
    $diffArtifact = @{
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
        version     = "1.0"
        policies    = @{
            new     = @()
            update  = @()
            replace = @()
            delete  = @()
        }
        policySets  = @{
            new     = @()
            update  = @()
            replace = @()
            delete  = @()
        }
        assignments = @{
            new     = @()
            update  = @()
            replace = @()
            delete  = @()
        }
        exemptions  = @{
            new     = @()
            update  = @()
            delete  = @()
        }
        roles       = @{
            added   = @()
            removed = @()
        }
    }
    
    # Process policy plan
    if ($PolicyPlan) {
        foreach ($action in @("new", "update", "replace", "delete")) {
            $resourceType = $null
            switch ($action) {
                "new" { $resourceType = "policy" }
                "update" { $resourceType = "policy" }
                "replace" { $resourceType = "policy" }
                "delete" { $resourceType = "policy" }
            }
            
            # Process policies
            if ($PolicyPlan.policies -and $PolicyPlan.policies.$action) {
                foreach ($resource in $PolicyPlan.policies.$action.PSObject.Properties) {
                    $entry = @{
                        id   = $resource.Name
                        name = $resource.Value.name
                    }
                    if ($resource.Value.diff) {
                        $entry.diff = $resource.Value.diff
                    }
                    $diffArtifact.policies.$action += , $entry
                }
            }
            
            # Process policy sets
            if ($PolicyPlan.policySets -and $PolicyPlan.policySets.$action) {
                foreach ($resource in $PolicyPlan.policySets.$action.PSObject.Properties) {
                    $entry = @{
                        id   = $resource.Name
                        name = $resource.Value.name
                    }
                    if ($resource.Value.diff) {
                        $entry.diff = $resource.Value.diff
                    }
                    $diffArtifact.policySets.$action += , $entry
                }
            }
            
            # Process assignments
            if ($PolicyPlan.assignments -and $PolicyPlan.assignments.$action) {
                foreach ($resource in $PolicyPlan.assignments.$action.PSObject.Properties) {
                    $entry = @{
                        id   = $resource.Name
                        name = $resource.Value.displayName
                    }
                    if ($resource.Value.diff) {
                        $entry.diff = $resource.Value.diff
                    }
                    $diffArtifact.assignments.$action += , $entry
                }
            }
            
            # Process exemptions
            if ($PolicyPlan.exemptions -and $PolicyPlan.exemptions.$action) {
                foreach ($resource in $PolicyPlan.exemptions.$action.PSObject.Properties) {
                    $entry = @{
                        id   = $resource.Name
                        name = $resource.Value.displayName
                    }
                    if ($resource.Value.diff) {
                        $entry.diff = $resource.Value.diff
                    }
                    $diffArtifact.exemptions.$action += , $entry
                }
            }
        }
    }
    
    # Process roles plan
    if ($RolesPlan) {
        if ($RolesPlan.added) {
            foreach ($role in $RolesPlan.added) {
                $diffArtifact.roles.added += @{
                    principalId = $role.principalId
                    roleId      = $role.roleDefinitionId
                    scope       = $role.scope
                }
            }
        }
        if ($RolesPlan.removed) {
            foreach ($role in $RolesPlan.removed) {
                $diffArtifact.roles.removed += @{
                    principalId = $role.principalId
                    roleId      = $role.roleDefinitionId
                    scope       = $role.scope
                }
            }
        }
    }
    
    # Write artifact to file
    $artifactPath = Join-Path $OutputFolder "policy-diff.json"
    $diffArtifact | ConvertTo-Json -Depth 100 | Out-File -FilePath $artifactPath -Encoding utf8 -Force
}
