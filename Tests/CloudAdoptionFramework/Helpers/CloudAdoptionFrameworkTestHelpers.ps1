Set-StrictMode -Version Latest

function Set-TestJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [object] $Object
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $null = New-Item -Path $parent -ItemType Directory -Force
    }

    $Object | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding utf8
}

function Get-TestJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [switch] $AsHashtable
    )

    $content = Get-Content -Path $Path -Raw
    if ($AsHashtable) {
        return $content | ConvertFrom-Json -AsHashtable
    }

    return $content | ConvertFrom-Json
}

function New-TestDefinitionsRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $DefinitionsRootFolder,

        [string] $PacEnvironmentSelector = 'epac-dev'
    )

    $null = New-Item -Path $DefinitionsRootFolder -ItemType Directory -Force
    foreach ($folder in @('policyAssignments', 'policySetDefinitions', 'policyDefinitions', 'policyDocumentations', 'policyStructures')) {
        $null = New-Item -Path (Join-Path $DefinitionsRootFolder $folder) -ItemType Directory -Force
    }

    $globalSettings = [ordered]@{
        '$schema'        = 'https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json'
        telemetryOptOut  = $true
        pacOwnerId       = [guid]::NewGuid().Guid
        pacEnvironments  = @(
            [ordered]@{
                pacSelector         = $PacEnvironmentSelector
                deploymentRootScope = '/providers/Microsoft.Management/managementGroups/test-root'
            }
        )
    }

    Set-TestJsonFile -Path (Join-Path $DefinitionsRootFolder 'global-settings.jsonc') -Object $globalSettings

    return $DefinitionsRootFolder
}

function New-TestPolicyDefinitionFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Category,

        [string] $DisplayName = $Name,

        [string] $Description = "$Name description"
    )

    $definition = [ordered]@{
        name       = $Name
        properties = [ordered]@{
            displayName = $DisplayName
            description = $Description
            metadata    = [ordered]@{
                category = $Category
            }
            policyRule  = [ordered]@{
                if   = [ordered]@{
                    field  = 'type'
                    equals = 'Microsoft.Resources/subscriptions'
                }
                then = [ordered]@{
                    effect = 'audit'
                }
            }
            parameters  = [ordered]@{}
            policyType  = 'Custom'
        }
    }

    Set-TestJsonFile -Path $Path -Object $definition
}

function New-TestPolicySetDefinitionFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Category,

        [string] $DisplayName = $Name,

        [string] $Description = "$Name policy set",

        [string] $PolicyDefinitionName = 'Audit-Policy'
    )

    $definition = [ordered]@{
        name       = $Name
        properties = [ordered]@{
            description            = $Description
            displayName            = $DisplayName
            metadata               = [ordered]@{
                category = $Category
            }
            parameters             = [ordered]@{
                effect = [ordered]@{
                    type = 'String'
                }
            }
            policyDefinitions      = @(
                [ordered]@{
                    parameters                  = [ordered]@{
                        effect = [ordered]@{
                            value = 'Audit'
                        }
                    }
                    groupNames                  = @()
                    policyDefinitionReferenceId = 'primary'
                    policyDefinitionId          = "/providers/Microsoft.Management/managementGroups/test-root/providers/Microsoft.Authorization/policyDefinitions/$PolicyDefinitionName"
                }
            )
            policyType             = 'Custom'
            policyDefinitionGroups = @()
        }
    }

    Set-TestJsonFile -Path $Path -Object $definition
}

function New-TestPolicyAssignmentFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $DisplayName,

        [Parameter(Mandatory = $true)]
        [string] $Description,

        [Parameter(Mandatory = $true)]
        [string] $PolicyDefinitionId,

        [hashtable] $Parameters = @{ },

        [string] $DefinitionVersion = '1.0.0',

        [string] $NonComplianceMessage = 'You {enforcementMode} follow this policy.'
    )

    $parameterObject = [ordered]@{}
    foreach ($key in $Parameters.Keys) {
        $parameterObject[$key] = [ordered]@{
            value = $Parameters[$key]
        }
    }

    $assignment = [ordered]@{
        name       = $Name
        properties = [ordered]@{
            displayName      = $DisplayName
            description      = $Description
            policyDefinitionId = $PolicyDefinitionId
            parameters       = $parameterObject
            definitionVersion = $DefinitionVersion
            nonComplianceMessages = [ordered]@{
                message = $NonComplianceMessage
            }
        }
    }

    Set-TestJsonFile -Path $Path -Object $assignment
}

function New-TestArchetypeDefinitionFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [AllowEmptyCollection()]
        [string[]] $PolicyAssignments
    )

    $definition = [ordered]@{
        '$schema'              = 'https://raw.githubusercontent.com/Azure/Azure-Landing-Zones-Library/main/schemas/archetype_definition.json'
        name                   = $Name
        policy_assignments     = $PolicyAssignments
        policy_definitions     = @()
        policy_set_definitions = @()
        role_definitions       = @()
    }

    Set-TestJsonFile -Path $Path -Object $definition
}

function New-AlzFixtureLibrary {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LibraryRoot,

        [ValidateSet('default', 'withoutPrivateDns')]
        [string] $Variant = 'default'
    )

    $root = Join-Path $LibraryRoot 'platform\alz'
    $managementGroups = @(
        [ordered]@{ id = 'alz';          display_name = 'Root';          archetypes = @('alz') },
        [ordered]@{ id = 'platform';     display_name = 'Platform';      archetypes = @('platform') },
        [ordered]@{ id = 'landingzones'; display_name = 'Landing Zones'; archetypes = @('landingzones') },
        [ordered]@{ id = 'identity';     display_name = 'Identity';      archetypes = @('identity') }
    )

    Set-TestJsonFile -Path (Join-Path $root 'architecture_definitions\alz.alz_architecture_definition.json') -Object @{
        management_groups = $managementGroups
    }

    $defaults = @(
        [ordered]@{
            default_name       = 'base_effect'
            description        = 'Default effect for Deploy-Base.'
            policy_assignments = @(
                [ordered]@{
                    policy_assignment_name = 'Deploy-Base'
                    parameter_names        = @('effect')
                }
            )
        },
        [ordered]@{
            default_name       = 'private_dns_zone_region'
            description        = 'Private DNS zone region.'
            policy_assignments = @(
                [ordered]@{
                    policy_assignment_name = 'Deploy-Private-DNS-Zones'
                    parameter_names        = @('region')
                }
            )
        },
        [ordered]@{
            default_name       = 'private_dns_zone_subscription_id'
            description        = 'Private DNS zone subscription.'
            policy_assignments = @(
                [ordered]@{
                    policy_assignment_name = 'Deploy-Private-DNS-Zones'
                    parameter_names        = @('subscriptionId')
                }
            )
        },
        [ordered]@{
            default_name       = 'private_dns_zone_resource_group_name'
            description        = 'Private DNS zone resource group.'
            policy_assignments = @(
                [ordered]@{
                    policy_assignment_name = 'Deploy-Private-DNS-Zones'
                    parameter_names        = @('resourceGroupName')
                }
            )
        }
    )

    Set-TestJsonFile -Path (Join-Path $root 'alz_policy_default_values.json') -Object @{
        defaults = $defaults
    }

    New-TestPolicyDefinitionFile -Path (Join-Path $root 'policy_definitions\Audit-Policy.json') -Name 'Audit-Policy' -Category 'General'
    New-TestPolicySetDefinitionFile -Path (Join-Path $root 'policy_set_definitions\Deploy-Base.json') -Name 'Deploy-Base' -Category 'General'

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy-Base.alz_policy_assignment.json') `
        -Name 'Deploy-Base' `
        -DisplayName 'Deploy Base' `
        -Description 'Base assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policySetDefinitions/Deploy-Base' `
        -Parameters @{ effect = 'Audit' }

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy-Private-DNS-Zones.alz_policy_assignment.json') `
        -Name 'Deploy-Private-DNS-Zones' `
        -DisplayName 'Deploy Private DNS Zones' `
        -Description 'Private DNS assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policyDefinitions/Deploy-Private-DNS-Zones' `
        -Parameters @{
            privateDnsZoneId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/placeholder/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
            region           = 'australiaeast'
            subscriptionId   = '11111111-1111-1111-1111-111111111111'
            resourceGroupName = 'networking-rg'
        }

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy-MDFC-DefSQL-AMA.alz_policy_assignment.json') `
        -Name 'Deploy-MDFC-DefSQL-AMA' `
        -DisplayName 'Deploy MDFC SQL AMA' `
        -Description 'ALZ MDFC SQL AMA assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policyDefinitions/Deploy-MDFC-DefSQL-AMA' `
        -Parameters @{
            userWorkspaceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/monitoring-rg/providers/Microsoft.OperationalInsights/workspaces/sql-law'
            workspaceRegion = 'australiaeast'
        }

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy-MDFC-Config-H224.alz_policy_assignment.json') `
        -Name 'Deploy-MDFC-Config-H224' `
        -DisplayName 'Deploy MDFC Config H224' `
        -Description 'ALZ MDFC configuration assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policyDefinitions/Deploy-MDFC-Config-H224' `
        -Parameters @{
            emailSecurityContact        = 'alerts@example.com'
            ascExportResourceGroupName  = 'mdfc-rg'
            ascExportResourceGroupLocation = 'australiaeast'
        }

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Enforce-GR-Test0.alz_policy_assignment.json') `
        -Name 'Enforce-GR-Test0' `
        -DisplayName 'Enforce Guardrail Test' `
        -Description 'Guardrail assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policyDefinitions/Enforce-GR-Test0'

    $landingZoneAssignments = if ($Variant -eq 'withoutPrivateDns') {
        @()
    }
    else {
        @('Deploy-Private-DNS-Zones')
    }

    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\alz.alz_archetype_definition.json') -Name 'alz' -PolicyAssignments @('Deploy-Base', 'Audit-Policy', 'Deploy-MDFC-DefSQL-AMA', 'Deploy-MDFC-Config-H224')
    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\platform.alz_archetype_definition.json') -Name 'platform' -PolicyAssignments @('Enforce-GR-Test0')
    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\landingzones.alz_archetype_definition.json') -Name 'landingzones' -PolicyAssignments $landingZoneAssignments
    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\identity.alz_archetype_definition.json') -Name 'identity' -PolicyAssignments @('Deploy-Base')
}

function New-AmbaFixtureLibrary {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LibraryRoot
    )

    $root = Join-Path $LibraryRoot 'platform\amba'
    Set-TestJsonFile -Path (Join-Path $root 'architecture_definitions\amba.alz_architecture_definition.json') -Object @{
        management_groups = @(
            [ordered]@{ id = 'alz';          display_name = 'Root';          archetypes = @('alz') },
            [ordered]@{ id = 'landingzones'; display_name = 'Landing Zones'; archetypes = @('landingzones') }
        )
    }

    Set-TestJsonFile -Path (Join-Path $root 'alz_policy_default_values.json') -Object @{
        defaults = @(
            [ordered]@{
                default_name       = 'log_analytics_workspace_id'
                description        = 'AMBA workspace id.'
                policy_assignments = @(
                    [ordered]@{
                        policy_assignment_name = 'Deploy-AMBA-Base'
                        parameter_names        = @('workspaceId')
                    }
                )
            }
        )
    }

    New-TestPolicyDefinitionFile -Path (Join-Path $root 'policy_definitions\AMBA-Policy.json') -Name 'AMBA-Policy' -Category 'Monitoring'
    New-TestPolicySetDefinitionFile -Path (Join-Path $root 'policy_set_definitions\Deploy-AMBA-Base.json') -Name 'Deploy-AMBA-Base' -Category 'Monitoring' -PolicyDefinitionName 'AMBA-Policy'

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy_AMBA_Base.alz_policy_assignment.json') `
        -Name 'Deploy-AMBA-Base' `
        -DisplayName 'Deploy AMBA Base' `
        -Description 'AMBA base assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policySetDefinitions/Deploy-AMBA-Base' `
        -Parameters @{
            workspaceId = '/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/amba-rg/providers/Microsoft.OperationalInsights/workspaces/amba-law'
        }

    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\alz.alz_archetype_definition.json') -Name 'alz' -PolicyAssignments @('Deploy-AMBA-Base')
    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\landingzones.alz_archetype_definition.json') -Name 'landingzones' -PolicyAssignments @('Deploy-AMBA-Base')
}

function New-SlzFixtureLibrary {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LibraryRoot
    )

    $root = Join-Path $LibraryRoot 'platform\slz'
    Set-TestJsonFile -Path (Join-Path $root 'architecture_definitions\slz.alz_architecture_definition.json') -Object @{
        management_groups = @(
            [ordered]@{ id = 'slz'; display_name = 'Sovereign Root'; archetypes = @('sovereign_root') },
            [ordered]@{ id = 'l2';  display_name = 'Level 2';        archetypes = @('sovereign_l2_controls', 'sovereign_shared') }
        )
    }

    Set-TestJsonFile -Path (Join-Path $root 'alz_policy_default_values.json') -Object @{
        defaults = @(
            [ordered]@{
                default_name       = 'slz_effect'
                description        = 'SLZ effect.'
                policy_assignments = @(
                    [ordered]@{
                        policy_assignment_name = 'Deploy-SLZ-Root'
                        parameter_names        = @('effect')
                    }
                )
            }
        )
    }

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy-SLZ-Root.alz_policy_assignment.json') `
        -Name 'Deploy-SLZ-Root' `
        -DisplayName 'Deploy SLZ Root' `
        -Description 'SLZ root assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policyDefinitions/Deploy-SLZ-Root' `
        -Parameters @{ effect = 'Audit' }

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy-SLZ-L2-Controls.alz_policy_assignment.json') `
        -Name 'Deploy-SLZ-L2-Controls' `
        -DisplayName 'Deploy SLZ L2 Controls' `
        -Description 'SLZ level two controls assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policyDefinitions/Deploy-SLZ-L2-Controls'

    New-TestPolicyAssignmentFile -Path (Join-Path $root 'policy_assignments\Deploy-SLZ-Shared.alz_policy_assignment.json') `
        -Name 'Deploy-SLZ-Shared' `
        -DisplayName 'Deploy SLZ Shared' `
        -Description 'SLZ shared assignment' `
        -PolicyDefinitionId '/providers/Microsoft.Authorization/policyDefinitions/Deploy-SLZ-Shared'

    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\sovereign_root.alz_archetype_definition.json') -Name 'sovereign_root' -PolicyAssignments @('Deploy-SLZ-Root')
    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\sovereign_l2_controls.alz_archetype_definition.json') -Name 'sovereign_l2_controls' -PolicyAssignments @('Deploy-SLZ-L2-Controls')
    New-TestArchetypeDefinitionFile -Path (Join-Path $root 'archetype_definitions\sovereign_shared.alz_archetype_definition.json') -Name 'sovereign_shared' -PolicyAssignments @('Deploy-SLZ-Shared')
}

function New-AmbaExtendedFixtureLibrary {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LibraryRoot
    )

    New-TestPolicyDefinitionFile -Path (Join-Path $LibraryRoot 'services\Compute\virtualMachines\policy\amba-extended-alert.json') `
        -Name 'AMBA-Extended-Alert' `
        -Category 'Monitoring' `
        -DisplayName 'AMBA Extended Alert' `
        -Description 'Extended AMBA policy definition'
}

function New-CompositeLibraryFixture {
    param(
        [Parameter(Mandatory = $true)]
        [string] $LibraryRoot,

        [string[]] $Types = @('ALZ', 'AMBA', 'SLZ'),

        [ValidateSet('default', 'withoutPrivateDns')]
        [string] $AlzVariant = 'default'
    )

    $null = New-Item -Path $LibraryRoot -ItemType Directory -Force

    if ($Types -contains 'ALZ') {
        New-AlzFixtureLibrary -LibraryRoot $LibraryRoot -Variant $AlzVariant
    }

    if ($Types -contains 'AMBA') {
        New-AmbaFixtureLibrary -LibraryRoot $LibraryRoot
    }

    if ($Types -contains 'SLZ') {
        New-SlzFixtureLibrary -LibraryRoot $LibraryRoot
    }

    return $LibraryRoot
}

function Invoke-WithMockedGitClone {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $CloneMap,

        [Parameter(Mandatory = $true)]
        [scriptblock] $ScriptBlock
    )

    $existingFunction = if (Test-Path Function:\git) {
        (Get-Item Function:\git).ScriptBlock
    }
    else {
        $null
    }

    $global:TestGitCloneMap = $CloneMap
    Set-Item -Path Function:\git -Value {
        param(
            [Parameter(ValueFromRemainingArguments = $true)]
            [object[]] $Arguments
        )

        $argumentList = @($Arguments | ForEach-Object { "$_" })
        if ($argumentList[0] -ne 'clone') {
            throw "Unexpected git invocation: $($argumentList -join ' ')"
        }

        $sourceUrl = @($argumentList | Where-Object { $_ -match '^https?://' })[0]
        if (-not $global:TestGitCloneMap.ContainsKey($sourceUrl)) {
            throw "Unexpected git clone source: $sourceUrl"
        }

        $destination = $argumentList[-1]
        if (Test-Path -Path $destination) {
            Remove-Item -Path $destination -Recurse -Force
        }

        $null = New-Item -Path $destination -ItemType Directory -Force
        Get-ChildItem -Path $global:TestGitCloneMap[$sourceUrl] -Force | Copy-Item -Destination $destination -Recurse -Force
        $global:LASTEXITCODE = 0
    }

    try {
        & $ScriptBlock
    }
    finally {
        if ($null -eq $existingFunction) {
            Remove-Item -Path Function:\git -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path Function:\git -Value $existingFunction
        }

        Remove-Variable -Name TestGitCloneMap -Scope Global -ErrorAction SilentlyContinue
    }
}

function Invoke-TestPwshFile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptPath,

        [Parameter(Mandatory = $true)]
        [hashtable] $Parameters,

        [string] $WorkingDirectory = (Get-Location).Path,

        [Parameter(Mandatory = $true)]
        [string] $ArtifactRoot
    )

    $stdoutPath = Join-Path $ArtifactRoot ("{0}-stdout.txt" -f ([guid]::NewGuid().Guid))
    $stderrPath = Join-Path $ArtifactRoot ("{0}-stderr.txt" -f ([guid]::NewGuid().Guid))

    $argumentList = @('-NoLogo', '-NoProfile', '-File', $ScriptPath)
    foreach ($entry in ($Parameters.GetEnumerator() | Sort-Object Key)) {
        if ($null -eq $entry.Value) {
            continue
        }

        if ($entry.Value -is [bool]) {
            if ($entry.Value) {
                $argumentList += "-$($entry.Key)"
            }
            continue
        }

        if ($entry.Value -is [System.Array]) {
            $argumentList += "-$($entry.Key)"
            $argumentList += (($entry.Value | ForEach-Object { "$_" }) -join ',')
            continue
        }

        $argumentList += "-$($entry.Key)"
        $argumentList += "$($entry.Value)"
    }

    $process = Start-Process -FilePath 'pwsh' -ArgumentList $argumentList -WorkingDirectory $WorkingDirectory -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

    $stdout = if (Test-Path -Path $stdoutPath) { Get-Content -Path $stdoutPath -Raw } else { '' }
    $stderr = if (Test-Path -Path $stderrPath) { Get-Content -Path $stderrPath -Raw } else { '' }

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdout
        StdErr   = $stderr
        Output   = ((@($stdout, $stderr) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine).Trim()
    }
}
