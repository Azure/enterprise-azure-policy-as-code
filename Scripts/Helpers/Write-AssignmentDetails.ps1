function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $DisplayName,
        $Scope,
        $Prefix,
        $IdentityStatus,
        $ScopeTable,
        [switch] $DetailedOutput,
        $DeployedAssignment = $null,
        $DesiredAssignment = $null,
        $ChangedProperties = @()
    )

    $tenantScopes = $ScopeTable.keys
    $shortScope = $Scope -replace "/providers/Microsoft.Management", ""
    if ($Prefix -ne "") {
        if ($Prefix -like "*update*") {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "update" -Indent 4
        }
        elseif ($Prefix -like "*new*") {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "success" -Indent 4
        }
        elseif ($Prefix -like "*delete*") {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "error" -Indent 4
        }
        else {
            Write-ModernStatus -Message "$($Prefix): $($DisplayName) at $($shortScope)" -Status "error" -Indent 4
        }
    }
    else {
        Write-ModernStatus -Message "$($DisplayName) at $($shortScope)" -Status "info" -Indent 4
    }
    if ($IdentityStatus.requiresRoleChanges) {
        foreach ($role in $IdentityStatus.updated) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            $roleShortScopeSub = ($roleScope -split '/')[0..2] -join '/'
            if (!$role.properties.crossTenant) {
                Write-ModernStatus -Message "Update role assignment description: $($role.roleDisplayName) at $($roleShortScope)" -Status "update" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Update role assignment description: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "update" -Indent 6
            }
            if (($tenantScopes -notcontains $roleScope) -and ($tenantScopes -notcontains $roleShortScopeSub)) {
                Write-ModernStatus -Message "Role assignments to external scopes may cause false positives!" -Status "warning" -Indent 8
            }
        }
        foreach ($role in $IdentityStatus.added) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            $roleShortScopeSub = ($roleScope -split '/')[0..2] -join '/'
            if (!$role.properties.crossTenant) {
                Write-ModernStatus -Message "Add role: $($role.roleDisplayName) at $($roleShortScope)" -Status "success" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Add role: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "success" -Indent 6
            }
            if (($tenantScopes -notcontains $roleScope) -and ($tenantScopes -notcontains $roleShortScopeSub)) {
                Write-ModernStatus -Message "Role assignments to external scopes may cause false positives!" -Status "warning" -Indent 8
            }
        }
        foreach ($role in $IdentityStatus.removed) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            $roleShortScopeSub = ($roleScope -split '/')[0..2] -join '/'
            if (!$role.crossTenant) {
                Write-ModernStatus -Message "Remove role: $($role.roleDisplayName) at $($roleShortScope)" -Status "error" -Indent 6
            }
            else {
                Write-ModernStatus -Message "Remove role: $($role.roleDisplayName) at $($roleShortScope) (remote)" -Status "error" -Indent 6
            }
            if (($tenantScopes -notcontains $roleScope) -and ($tenantScopes -notcontains $roleShortScopeSub)) {
                Write-ModernStatus -Message "Role assignments to external scopes may cause false positives!" -Status "warning" -Indent 8
            }
        }
    }
    
    # Show detailed information if requested
    if ($DetailedOutput) {
        # Show details for deleted assignments
        if ($null -ne $DeployedAssignment -and $null -eq $DesiredAssignment) {
            Write-Host ""
            Write-ModernStatus -Message "[Policy Assignment] Details for Deleted Assignment:" -Status "info" -Indent 6
            
            $deployedProps = Get-PolicyResourceProperties -PolicyResource $DeployedAssignment
            
            # Display Name
            Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
            Write-ColoredOutput -Message "Display Name: " -NoNewline -ForegroundColor Gray
            Write-ColoredOutput -Message "`"$DisplayName`"" -ForegroundColor Red
            
            # Scope
            Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
            Write-ColoredOutput -Message "Scope: " -NoNewline -ForegroundColor Gray
            Write-ColoredOutput -Message $deployedProps.scope -ForegroundColor Red
            
            # Policy Definition ID
            if ($deployedProps.policyDefinitionId) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Policy Definition ID: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message $deployedProps.policyDefinitionId -ForegroundColor Red
            }
            
            # Description
            if ($deployedProps.description) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Description: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$($deployedProps.description)`"" -ForegroundColor Red
            }
            
            # Enforcement Mode
            if ($deployedProps.enforcementMode) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Enforcement Mode: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$($deployedProps.enforcementMode)`"" -ForegroundColor Red
            }
            
            # Identity
            if ($DeployedAssignment.identity) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Identity Type: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$($DeployedAssignment.identity.type)`"" -ForegroundColor Red
                if ($DeployedAssignment.identity.type -eq "SystemAssigned" -and $deployedProps.location) {
                    Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                    Write-ColoredOutput -Message "Identity Location: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "`"$($deployedProps.location)`"" -ForegroundColor Red
                }
            }
            
            # Parameters count if any
            if ($deployedProps.parameters) {
                $paramCount = ($deployedProps.parameters.PSObject.Properties | Measure-Object).Count
                if ($paramCount -gt 0) {
                    Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                    Write-ColoredOutput -Message "Parameters: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "$paramCount parameter(s)" -ForegroundColor Red
                }
            }
            
            # Metadata if any (excluding system properties)
            if ($deployedProps.metadata) {
                $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                $filteredMetadata = @{}
                foreach ($key in $deployedProps.metadata.Keys) {
                    if ($key -notin $systemManagedProperties -and $key -ne "pacOwnerId") {
                        $filteredMetadata[$key] = $deployedProps.metadata[$key]
                    }
                }
                if ($filteredMetadata.Count -gt 0) {
                    Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                    Write-ColoredOutput -Message "Metadata: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "$($filteredMetadata.Count) item(s)" -ForegroundColor Red
                }
            }
            
            # Not Scopes count if any
            if ($deployedProps.notScopes -and $deployedProps.notScopes.Count -gt 0) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Not Scopes: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "$($deployedProps.notScopes.Count) scope(s)" -ForegroundColor Red
            }
            
            # Non-Compliance Messages count if any
            if ($deployedProps.nonComplianceMessages -and $deployedProps.nonComplianceMessages.Count -gt 0) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Non-Compliance Messages: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "$($deployedProps.nonComplianceMessages.Count) message(s)" -ForegroundColor Red
            }
            
            # Overrides count if any
            if ($deployedProps.overrides -and $deployedProps.overrides.Count -gt 0) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Overrides: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "$($deployedProps.overrides.Count) override(s)" -ForegroundColor Red
            }
            
            # Resource Selectors count if any
            if ($deployedProps.resourceSelectors -and $deployedProps.resourceSelectors.Count -gt 0) {
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Resource Selectors: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "$($deployedProps.resourceSelectors.Count) selector(s)" -ForegroundColor Red
            }
            
            Write-Host ""
        }
        # Show details for new assignments
        elseif ($null -eq $DeployedAssignment -and $null -ne $DesiredAssignment) {
            Write-Host ""
            Write-ModernStatus -Message "[Policy Assignment] Details for New Assignment:" -Status "info" -Indent 6
            
            $desiredProps = Get-PolicyResourceProperties -PolicyResource $DesiredAssignment
            
            # Display scope
            if ($desiredProps.scope) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Scope: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message $desiredProps.scope -ForegroundColor Green
            }
            
            # Display policy definition with full path
            if ($desiredProps.policyDefinitionId) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Policy Definition ID: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message $desiredProps.policyDefinitionId -ForegroundColor Green
            }
            
            # Display description
            if ($desiredProps.description) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Description: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$($desiredProps.description)`"" -ForegroundColor Green
            }
            
            # Display enforcement mode (always show, even if Default)
            $enforcementMode = if ($desiredProps.enforcementMode) { $desiredProps.enforcementMode } else { "Default" }
            Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
            Write-ColoredOutput -Message "Enforcement Mode: " -NoNewline -ForegroundColor Gray
            $modeColor = if ($enforcementMode -eq "Default") { "Green" } else { "Yellow" }
            Write-Host "`"$enforcementMode`"" -ForegroundColor $modeColor
            
            # Display identity information
            if ($IdentityStatus.isUserAssigned) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Identity Type: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"UserAssigned`"" -ForegroundColor Green
            }
            elseif ($IdentityStatus.identityRequired) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Identity Type: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"SystemAssigned`"" -ForegroundColor Green
                if ($desiredProps.location) {
                    Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Identity Location: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "`"$($desiredProps.location)`"" -ForegroundColor Green
                }
            }
            
            # Display parameters if any
            if ($desiredProps.parameters -and $desiredProps.parameters.Count -gt 0) {
                Write-ColoredOutput -Message "        Parameters:" -ForegroundColor Gray
                $normalizedParams = @{}
                foreach ($key in $desiredProps.parameters.Keys) {
                    $param = $desiredProps.parameters[$key]
                    if ($param -is [hashtable] -and $null -ne $param.value -and $param -isnot [array]) {
                        $normalizedParams[$key] = $param.value
                    }
                    else {
                        $normalizedParams[$key] = $param
                    }
                }
                foreach ($key in ($normalizedParams.Keys | Sort-Object)) {
                    $value = $normalizedParams[$key]
                    if ($value -is [array]) {
                        Write-ColoredOutput -Message "          • " -NoNewline -ForegroundColor DarkGray
                        Write-ColoredOutput -Message "$key" -NoNewline -ForegroundColor White
                        Write-ColoredOutput -Message " = [" -ForegroundColor Gray
                        foreach ($item in $value) {
                            Write-Host "              " -NoNewline
                            Write-ColoredOutput -Message """$item""" -NoNewline -ForegroundColor Green
                            Write-ColoredOutput -Message "," -ForegroundColor Gray
                        }
                        Write-ColoredOutput -Message "            ]" -ForegroundColor Gray
                    }
                    elseif ($value -is [hashtable] -or $value -is [PSCustomObject]) {
                        Write-ColoredOutput -Message "          • " -NoNewline -ForegroundColor DarkGray
                        Write-ColoredOutput -Message "$key" -NoNewline -ForegroundColor White
                        Write-ColoredOutput -Message " = {" -ForegroundColor Gray
                        $valueJson = $value | ConvertTo-Json -Depth 10 -Compress
                        Write-ColoredOutput -Message "              $valueJson" -ForegroundColor Green
                        Write-ColoredOutput -Message "            }" -ForegroundColor Gray
                    }
                    else {
                        Write-ColoredOutput -Message "          • " -NoNewline -ForegroundColor DarkGray
                        Write-ColoredOutput -Message "$key" -NoNewline -ForegroundColor White
                        Write-ColoredOutput -Message " = " -NoNewline -ForegroundColor Gray
                        Write-ColoredOutput -Message """$value""" -ForegroundColor Green
                    }
                }
            }
            
            # Display metadata if any (excluding system properties)
            if ($desiredProps.metadata) {
                $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                $filteredMetadata = @{}
                foreach ($key in $desiredProps.metadata.Keys) {
                    if ($key -notin $systemManagedProperties -and $key -ne "pacOwnerId") {
                        $filteredMetadata[$key] = $desiredProps.metadata[$key]
                    }
                }
                if ($filteredMetadata.Count -gt 0) {
                    Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Metadata:" -ForegroundColor Gray
                    foreach ($key in ($filteredMetadata.Keys | Sort-Object)) {
                        Write-ColoredOutput -Message "            + " -NoNewline -ForegroundColor Green
                        Write-ColoredOutput -Message "$key" -NoNewline -ForegroundColor White
                        Write-ColoredOutput -Message " = " -NoNewline -ForegroundColor Gray
                        Write-ColoredOutput -Message "`"$($filteredMetadata[$key])`"" -ForegroundColor Green
                    }
                }
            }
            
            # Display not scopes if any
            if ($desiredProps.notScopes -and $desiredProps.notScopes.Count -gt 0) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Not Scopes:" -ForegroundColor Gray
                foreach ($notScope in $desiredProps.notScopes) {
                    Write-ColoredOutput -Message "            + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message $notScope -ForegroundColor Green
                }
            }
            
            # Display non-compliance messages if any
            if ($desiredProps.nonComplianceMessages -and $desiredProps.nonComplianceMessages.Count -gt 0) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Non-Compliance Messages:" -ForegroundColor Gray
                foreach ($msg in $desiredProps.nonComplianceMessages) {
                    Write-ColoredOutput -Message "            + " -NoNewline -ForegroundColor Green
                    if ($msg.policyDefinitionReferenceId) {
                        Write-ColoredOutput -Message "Policy Ref: " -NoNewline -ForegroundColor Gray
                        Write-ColoredOutput -Message $msg.policyDefinitionReferenceId -NoNewline -ForegroundColor Green
                        Write-ColoredOutput -Message " - " -NoNewline -ForegroundColor Gray
                    }
                    Write-ColoredOutput -Message $msg.message -ForegroundColor Green
                }
            }
            
            # Display overrides if any
            if ($desiredProps.overrides -and $desiredProps.overrides.Count -gt 0) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Overrides:" -ForegroundColor Gray
                foreach ($override in $desiredProps.overrides) {
                    Write-ColoredOutput -Message "            + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Kind: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message $override.kind -NoNewline -ForegroundColor Green
                    if ($override.value) {
                        Write-ColoredOutput -Message ", Value: " -NoNewline -ForegroundColor Gray
                        Write-ColoredOutput -Message $override.value -ForegroundColor Green
                    }
                    if ($override.selectors -and $override.selectors.Count -gt 0) {
                        Write-ColoredOutput -Message "              Selectors: $($override.selectors.Count)" -ForegroundColor Gray
                    }
                }
            }
            
            # Display resource selectors if any
            if ($desiredProps.resourceSelectors -and $desiredProps.resourceSelectors.Count -gt 0) {
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Resource Selectors:" -ForegroundColor Gray
                foreach ($selector in $desiredProps.resourceSelectors) {
                    Write-ColoredOutput -Message "            + " -NoNewline -ForegroundColor Green
                    if ($selector.name) {
                        Write-ColoredOutput -Message $selector.name -NoNewline -ForegroundColor Green
                        if ($selector.selectors -and $selector.selectors.Count -gt 0) {
                            Write-ColoredOutput -Message " ($($selector.selectors.Count) selector(s))" -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-ColoredOutput -Message "$($selector.selectors.Count) selector(s)" -ForegroundColor Green
                    }
                }
            }
            
            Write-Host ""
        }
        # Show detailed diffs for updates
        elseif ($null -ne $DeployedAssignment -and $null -ne $DesiredAssignment -and $ChangedProperties.Count -gt 0) {
            Write-Host ""
            Write-ModernStatus -Message "[Policy Assignment] Detailed Property Changes:" -Status "info" -Indent 6
            
            $deployedProps = Get-PolicyResourceProperties -PolicyResource $DeployedAssignment
            $desiredProps = Get-PolicyResourceProperties -PolicyResource $DesiredAssignment
            
            foreach ($changedProp in $ChangedProperties) {
                switch ($changedProp) {
                    "displayName" {
                        Write-SimplePropertyDiff -PropertyName "Display Name" -OldValue $deployedProps.displayName -NewValue $desiredProps.displayName -Indent 8
                    }
                "description" {
                    Write-SimplePropertyDiff -PropertyName "Description" -OldValue $deployedProps.description -NewValue $desiredProps.description -Indent 8
                }
                "enforcementMode" {
                    Write-SimplePropertyDiff -PropertyName "Enforcement Mode" -OldValue $deployedProps.enforcementMode -NewValue $desiredProps.enforcementMode -Indent 8
                }
                "definitionVersion" {
                    Write-SimplePropertyDiff -PropertyName "Definition Version" -OldValue $deployedProps.definitionVersion -NewValue $desiredProps.definitionVersion -Indent 8
                }
                "parameters" {
                    # Normalize parameters for display - remove .value wrappers from both deployed and desired params
                    # This matches the normalization done in Confirm-ParametersUsageMatches for comparison
                    # Note: Desired parameters may omit values that match policy definition defaults,
                    # so we merge deployed params with desired params to show only actual changes
                    $normalizedDeployedParams = @{}
                    $normalizedDesiredParams = @{}
                    
                    if ($deployedProps.parameters) {
                        foreach ($key in $deployedProps.parameters.Keys) {
                            $param = $deployedProps.parameters[$key]
                            if ($param -is [hashtable] -and $param.ContainsKey("value")) {
                                $normalizedDeployedParams[$key] = $param.value
                            }
                            else {
                                $normalizedDeployedParams[$key] = $param
                            }
                        }
                    }
                    
                    if ($desiredProps.parameters) {
                        foreach ($key in $desiredProps.parameters.Keys) {
                            $param = $desiredProps.parameters[$key]
                            # Check if parameter has .value wrapper and is not an array
                            # This matches the logic in Confirm-ParametersUsageMatches
                            if ($param -is [hashtable] -and $null -ne $param.value -and $param -isnot [array]) {
                                $normalizedDesiredParams[$key] = $param.value
                            }
                            else {
                                $normalizedDesiredParams[$key] = $param
                            }
                        }
                    }
                    
                    # For parameters that exist in deployed but not in desired, copy them to desired
                    # This handles parameters that match policy definition defaults and are omitted from assignment
                    foreach ($key in $normalizedDeployedParams.Keys) {
                        if (-not $normalizedDesiredParams.ContainsKey($key)) {
                            $normalizedDesiredParams[$key] = $normalizedDeployedParams[$key]
                        }
                    }
                    
                    Write-DetailedDiff -DeployedObject $normalizedDeployedParams -DesiredObject $normalizedDesiredParams -PropertyName "Parameters" -Indent 8
                }
                "metadata" {
                    # Filter Azure system-managed properties and EPAC-managed pacOwnerId from metadata display
                    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                    $filteredDeployedMetadata = @{}
                    $filteredDesiredMetadata = @{}
                    
                    if ($deployedProps.metadata) {
                        foreach ($key in $deployedProps.metadata.Keys) {
                            if ($key -notin $systemManagedProperties -and $key -ne "pacOwnerId") {
                                $filteredDeployedMetadata[$key] = $deployedProps.metadata[$key]
                            }
                        }
                    }
                    
                    if ($desiredProps.metadata) {
                        foreach ($key in $desiredProps.metadata.Keys) {
                            if ($key -ne "pacOwnerId") {
                                $filteredDesiredMetadata[$key] = $desiredProps.metadata[$key]
                            }
                        }
                    }
                    
                    Write-DetailedDiff -DeployedObject $filteredDeployedMetadata -DesiredObject $filteredDesiredMetadata -PropertyName "Metadata" -Indent 8
                }
                "notScopes" {
                    Write-DetailedDiff -DeployedObject $deployedProps.notScopes -DesiredObject $desiredProps.notScopes -PropertyName "Not Scopes" -Indent 8
                }
                "nonComplianceMessages" {
                    Write-DetailedDiff -DeployedObject $deployedProps.nonComplianceMessages -DesiredObject $desiredProps.nonComplianceMessages -PropertyName "Non-Compliance Messages" -Indent 8
                }
                "overrides" {
                    Write-DetailedDiff -DeployedObject $deployedProps.overrides -DesiredObject $desiredProps.overrides -PropertyName "Overrides" -Indent 8
                }
                "resourceSelectors" {
                    Write-DetailedDiff -DeployedObject $deployedProps.resourceSelectors -DesiredObject $desiredProps.resourceSelectors -PropertyName "Resource Selectors" -Indent 8
                }
            }
        }
        Write-Host ""
        }
    }
}


