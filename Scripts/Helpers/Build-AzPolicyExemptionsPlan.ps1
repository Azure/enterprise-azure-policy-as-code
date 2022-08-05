#Requires -PSEdition Core

function Build-AzPolicyExemptionsPlan {
    [CmdletBinding()]
    param (
        [string] $pacEnvironmentSelector,
        [string] $exemptionsRootFolder,
        [bool] $noDelete,
        [hashtable] $allAssignments,
        [hashtable] $replacedAssignments,
        [hashtable] $existingExemptions,
        [hashtable] $newExemptions,
        [hashtable] $updatedExemptions,
        [hashtable] $replacedExemptions,
        [hashtable] $deletedExemptions,
        [hashtable] $unchangedExemptions,
        [hashtable] $orphanedExemptions,
        [hashtable] $expiredExemptions
    )

    $path = "$($exemptionsRootFolder)/$pacEnvironmentSelector"
    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Exemption files in folder '$path'"
    Write-Information "==================================================================================================="
    [array] $exemptionFiles = @()
    if (Test-Path $path) {
        # Do not manage exemptions if directory does not exist
        $exemptionFiles += Get-ChildItem -Path $path -Recurse -File -Filter "*.json"
        $exemptionFiles += Get-ChildItem -Path $path -Recurse -File -Filter "*.jsonc"
        $exemptionFiles += Get-ChildItem -Path $path -Recurse -File -Filter "*.csv"

        [hashtable] $allExemptions = @{}
        [hashtable] $obsoleteExemptions = $existingExemptions.Clone()
        if ($exemptionFiles.Length -gt 0) {
            Write-Information "Number of Policy Exemption files = $($exemptionFiles.Length)"
            $now = Get-Date -AsUTC
            foreach ($file  in $exemptionFiles) {
                $exemptionArray = @()
                $extension = $file.Extension
                $fullName = $file.FullName
                $fileName = $file.Name
                $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                Write-Information $fileName
                if ($extension -eq ".json" -or $extension -eq ".jsonc") {
                    if (!(Test-Json $content)) {
                        Write-Error "  Invalid JSON" -ErrorAction Stop
                    }
                    $jsonObj = ConvertFrom-Json $content -AsHashtable -Depth 100
                    if ($null -ne $jsonObj) {
                        $jsonExemptions = $jsonObj.exemptions
                        if ($null -ne $jsonExemptions -and $jsonExemptions.Count -gt 0) {
                            $exemptionArray += $jsonExemptions
                        }
                    }
                }
                elseif ($extension -eq ".csv") {
                    $xlsExemptionArray = @() + ($content | ConvertFrom-Csv -ErrorAction Stop)
                    # Adjust flat structure from spreadsheets to the almost flat structure in JSON
                    [System.Collections.ArrayList] $exemptionArrayList = [System.Collections.ArrayList]::new()
                    foreach ($row in $xlsExemptionArray) {
                        $policyDefinitionReferenceIds = @()
                        $step1 = $row.policyDefinitionReferenceIds
                        if ($null -ne $step1 -and $step1 -ne "") {
                            $step2 = $step1.Trim()
                            $step3 = $step2 -split ","
                            foreach ($item in $step3) {
                                $step4 = $item.Trim()
                                if ($step4.Length -gt 0) {
                                    $policyDefinitionReferenceIds += $step4
                                }
                            }
                        }
                        $metadata = $null
                        $step1 = $row.metadata
                        if ($null -ne $step1 -and $step1 -ne "") {
                            $step2 = $step1.Trim()
                            if ($step2.StartsWith("{") -and (Test-Json $step2)) {
                                $step3 = ConvertFrom-Json $step2 -AsHashtable -Depth 100
                                if ($step3 -ne @{}) {
                                    $metadata = $step3
                                }
                            }
                            else {
                                Write-Error "  Invalid metadata format, must be empty or legal JSON: '$step2'"
                            }
                        }
                        $exemption = [ordered]@{
                            name                         = $row.name
                            displayName                  = $row.displayName
                            description                  = $row.description
                            exemptionCategory            = $row.exemptionCategory
                            expiresOn                    = $row.expiresOn
                            scope                        = $row.scope
                            policyAssignmentId           = $row.policyAssignmentId
                            policyDefinitionReferenceIds = $policyDefinitionReferenceIds
                            metadata                     = $metadata
                        }
                        $null = $exemptionArrayList.Add($exemption)
                    }
                    $exemptionArray = $exemptionArrayList.ToArray()
                }
                else {
                    Write-Information "Unknown file extension $fileName"
                    continue
                }

                foreach ($exemptionRaw in $exemptionArray) {

                    # Validate the content,  remove extraneous columns
                    $name = $exemptionRaw.name
                    $displayName = $exemptionRaw.displayName
                    $description = $exemptionRaw.description
                    $exemptionCategory = $exemptionRaw.exemptionCategory
                    $scope = $exemptionRaw.scope
                    $policyAssignmentId = $exemptionRaw.policyAssignmentId
                    $policyDefinitionReferenceIds = $exemptionRaw.policyDefinitionReferenceIds
                    $metadata = $exemptionRaw.metadata
                    if (($null -eq $name -or $name -eq '') -or ($null -eq $exemptionCategory -or $exemptionCategory -eq '') -or ($null -eq $scope -or $scope -eq '') -or ($null -eq $policyAssignmentId -or $policyAssignmentId -eq '')) {
                        if (-not (($null -eq $name -or $name -eq '') -and ($null -eq $exemptionCategory -or $exemptionCategory -eq '') `
                                    -and ($null -eq $scope -or $scope -eq '') -and ($null -eq $policyAssignmentId -or $policyAssignmentId -eq '') `
                                    -and ($null -eq $displayName -or $displayName -eq "") -and ($null -eq $description -or $description -eq "") `
                                    -and ($null -eq $expiresOnRaw -or $expiresOnRaw -eq "") -and ($null -eq $metadata) `
                                    -and ($null -eq $policyDefinitionReferenceIds -or $policyDefinitionReferenceIds.Count -eq 0))) {
                            #ignore empty lines from Excel or CSV
                            Write-Error "  Exemption is missing one or more of required fields name($name), scope($scope) and policyAssignmentId($policyAssignmentId)" -ErrorAction Stop
                        }
                    }
                    $exemption = @{
                        Name               = $name
                        Scope              = $scope
                        policyAssignmentId = $policyAssignmentId
                        ExemptionCategory  = $exemptionCategory
                    }
                    if ($displayName -and $displayName -ne "") {
                        $null = $exemption.Add("DisplayName", $displayName)
                    }
                    else {
                        $displayName = $null
                    }
                    if ($description -and $description -ne "") {
                        $null = $exemption.Add("Description", $description)
                    }
                    else {
                        $description = $null
                    }

                    $expiresOn = $null
                    $expired = $false
                    $expiresOnRaw = $exemptionRaw.expiresOn
                    if ($null -ne $expiresOnRaw) {
                        if ($expiresOnRaw -is [datetime]) {
                            $expiresOn = $expiresOnRaw
                        }
                        elseif ($expiresOnRaw -is [string]) {
                            if ($expiresOnRaw -ne "") {
                                try {
                                    $expiresOn = [datetime]::Parse($expiresOnRaw, $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                }
                                catch {
                                    Write-Error "$_" -ErrorAction Stop
                                }
                            }
                        }
                        else {
                            Write-Error "expiresOn field '$($expiresOnRaw)' is not a recognized type $($expiresOnRaw.GetType().Name)" -ErrorAction Stop
                        }
                    }
                    if ($null -ne $expiresOn) {
                        $expired = $expiresOn -lt $now
                        $null = $exemption.Add("ExpiresOn", $expiresOn)
                    }

                    if ($policyDefinitionReferenceIds -and $policyDefinitionReferenceIds.Count -gt 0) {
                        $null = $exemption.Add("PolicyDefinitionReferenceIds", $policyDefinitionReferenceIds)
                    }
                    else {
                        $policyDefinitionReferenceIds = $null
                    }
                    if ($metadata -and $metadata -ne @{} -and $metadata -ne "") {
                        $null = $exemption.Add("Metadata", $metadata)
                    }
                    else {
                        $metadata = $null
                    }
                    $id = "$scope/providers/Microsoft.Authorization/policyExemptions/$name"

                    # Check for duplicates
                    if ($allExemptions.ContainsKey($id) -or $orphanedExemptions.ContainsKey($id) -or $expiredExemptions.ContainsKey($id)) {
                        Write-Error "  Duplicate exemption id (name=$name, scope=$scope)" -ErrorAction Stop
                    }

                    # Filter orhaned and expired Exemptions
                    if ($expired) {
                        $null = $expiredExemptions.Add($id, $exemption)
                        continue
                    }
                    if (-not $allAssignments.ContainsKey($policyAssignmentId)) {
                        $null = $orphanedExemptions.Add($id, $exemption)
                        continue
                    }

                    # Calculate desired state mandated changes
                    $null = $allExemptions.Add($id, $exemption)
                    if ($existingExemptions.ContainsKey($id)) {
                        $obsoleteExemptions.Remove($id)
                        $existingExemption = $existingExemptions.$id
                        if ($existingExemption.policyAssignmentId -ne $policyAssignmentId) {
                            # Replaced Assignment
                            Write-Information "Replace(assignment) '$($name)', '$($scope)'"
                            $null = $replacedExemptions.Add($id, $exemption)
                        }
                        elseif ($replacedAssignments.ContainsKey($policyAssignmentId)) {
                            # Replaced Assignment
                            Write-Information "Replace(reference) '$($name)', '$($scope)'"
                            $null = $replacedExemptions.Add($id, $exemption)
                        }
                        else {
                            # Maybe update existing Exemption
                            $displayNameMatches = $existingExemption.displayName -eq $displayName
                            $descriptionMatches = $existingExemption.description -eq $description
                            $exemptionCategoryMatches = $existingExemption.exemptionCategory -eq $exemptionCategory
                            $expiresOnMatches = $existingExemption.expiresOn -eq $expiresOn
                            $clearExpiration = $false
                            if (-not $expiresOnMatches) {
                                if ($null -eq $expiresOn) {
                                    $null = $exemption.Add("ClearExpiration", $true)
                                    $clearExpiration = $true
                                }
                            }
                            $policyDefinitionReferenceIdsMatches = Confirm-ObjectValueEqualityDeep -existingObj $existingExemption.policyDefinitionReferenceIds -definedObj $policyDefinitionReferenceIds
                            $metadataMatches = Confirm-MetadataMatches `
                                -existingMetadataObj $existingExemption.metadata `
                                -definedMetadataObj $metadata
                            # Update policy definition in Azure if necessary
                            if ($displayNameMatches -and $descriptionMatches -and $exemptionCategoryMatches -and $expiresOnMatches -and $policyDefinitionReferenceIdsMatches -and $metadataMatches -and (-not $clearExpiration)) {
                                # Write-Information "Unchanged '$($name)' - '$($displayName)'"
                                $null = $unchangedExemptions.Add($id, $displayName)
                            }
                            else {
                                $changesString = ($displayNameMatches ? "-" : "n") `
                                    + ($descriptionMatches ? "-" : "d") `
                                    + ($metadataMatches ? "-": "m") `
                                    + ($exemptionCategoryMatches ? "-": "c") `
                                    + ($expiresOnMatches ? "-": "x") `
                                    + ($clearExpiration ? "c": "-") `
                                    + ($policyDefinitionReferenceIdsMatches ? "-": "r")

                                Write-Information "Update($changesString) '$($name)', '$($scope)'"
                                $null = $exemption.Add("Id", $id)
                                $null = $updatedExemptions.Add($id, $exemption)
                            }
                        }
                    }
                    else {
                        # Create Exemption
                        Write-Information "New '$($name)', '$($scope)'"
                        $null = $newExemptions.Add($id, $exemption)
                    }
                }
            }

            if ($unchangedExemptions.Count -gt 0) {
                Write-Information "$($unchangedExemptions.Count) unchanged Exemptions"
            }
            if ($orphanedExemptions.Count -gt 0) {
                Write-Information "$($orphanedExemptions.Count) orphaned Exemptions in definition files"
                foreach ($id in $orphanedExemptions.Keys) {
                    $exemption = $orphanedExemptions[$id]
                    Write-Information "    $($exemption.name), $($exemption.scope), $($exemption.policyAssignmentId)"
                }
            }
            if ($expiredExemptions.Count -gt 0) {
                Write-Information "$($expiredExemptions.Count) expired Exemptions in definition files"
                foreach ($id in $expiredExemptions.Keys) {
                    $exemption = $expiredExemptions[$id]
                    Write-Information "    $($exemption.name), $($exemption.scope), $($exemption.policyAssignmentId)"
                }
            }
            if ($obsoleteExemptions.Count -gt 0) {
                if ($noDelete) {
                    Write-Information "Suppressing delete Exemptions ($($obsoleteExemptions.Count))"
                    foreach ($id in $obsoleteExemptions.Keys) {
                        $exemption = $existingExemptions[$id]
                        Write-Information "    $($exemption.displayName), $($exemption.name), $($exemption.scope)"
                    }
                }
                else {
                    Write-Information "Delete Exemptions ($($obsoleteExemptions.Count))"
                    foreach ($id in $obsoleteExemptions.Keys) {
                        $exemption = $existingExemptions[$id]
                        Write-Information "    $($exemption.name), $($exemption.displayName), $($exemption.scope)"
                        $deletedExemptions.Add($id, $exemption)
                    }
                }
            }
            Write-Information ""
            Write-Information ""
        }
        else {
            Write-Information "Warning: no Exemptions files for EPAC environment $pacEnvironmentSelector in directory '$path'!"
        }
    }
    else {
        Write-Information "Exemptions for EPAC environment $pacEnvironmentSelector are not managed by EPAC. To manage them craete a folder named '$path'."
    }
}
