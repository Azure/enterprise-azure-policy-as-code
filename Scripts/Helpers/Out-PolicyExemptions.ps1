function Out-PolicyExemptions {
    [CmdletBinding()]
    param (
        $Exemptions,
        $Assignments,
        $PacEnvironment,
        $PolicyExemptionsFolder,
        [switch] $OutputJson,
        [switch] $OutputCsv,
        [string] $FileExtension = "json",
        [switch] $ActiveExemptionsOnly,
        [switch] $ExportForEpac
    )

    $numberOfExemptions = $Exemptions.Count
    Write-ModernSection -Title "Outputting Policy Exemptions" -Color Blue
    Write-ModernStatus -Message "Found $numberOfExemptions exemptions" -Status "success" -Indent 2

    $pacSelector = $PacEnvironment.pacSelector
    $outputPath = "$PolicyExemptionsFolder/$pacSelector"
    if (-not (Test-Path $outputPath)) {
        $null = New-Item $outputPath -Force -ItemType directory
    }

    
    #region Sort Metadata and epacMetaData
    $exemptionskeys = $Exemptions.Keys
    foreach ($key in $exemptionskeys) {
        # Create a new ordered hash table
        $orderedMetadata = [ordered]@{}
        # Get the properties of the original object and sort them alphabetically
        $metadataKeys = $Exemptions.$($key).metadata.Keys | Sort-Object
        # Add the sorted properties to the new ordered hash table
        foreach ($metadataKey in $metadataKeys) {
            $orderedMetadata.$metadataKey = $Exemptions.$($key).metadata.$metadataKey
        }
        $Exemptions.$($key).metadata = $orderedMetadata
    }

    $exemptionskeys = $Exemptions.Keys
    foreach ($key in $exemptionskeys) {
        # Create a new ordered hash table
        $orderedEpacMetadata = [ordered]@{}
        # Get the properties of the original object and sort them alphabetically
        $epacMetadataKeys = $Exemptions.$($key).metadata.epacMetadata.Keys | Sort-Object
        # Add the sorted properties to the new ordered hash table
        foreach ($epacMetadataKey in $epacMetadataKeys) {
            $orderedEpacMetadata.$epacMetadataKey = $Exemptions.$($key).metadata.epacMetadata.$epacMetadataKey
        }
        $Exemptions.$($key).metadata.epacMetadata = $orderedEpacMetadata
    }

    #region Transformations

    $policyDefinitionReferenceIdsTransform = @{
        label      = "policyDefinitionReferenceIds"
        expression = {
            if ($_.policyDefinitionReferenceIds) {
                ($_.policyDefinitionReferenceIds -join "&").ToString()
            }
            else {
                ''
            }
        }
    }
    $metadataTransformCsv = @{
        label      = "metadata"
        expression = {
            if ($_.metadata) {
                $step1 = Get-CustomMetadata -Metadata $_.metadata -Remove "pacOwnerId"
                $temp = (ConvertTo-Json $step1 -Depth 100 -Compress).ToString()
                if ($temp -eq "{}") {
                    ''
                }
                else {
                    $temp
                }
            }
            else {
                ''
            }
        }
    }
    $metadataTransformJson = @{
        label      = "metadata"
        expression = {
            if ($_.metadata) {
                $temp = Get-CustomMetadata -Metadata $_.metadata -Remove "pacOwnerId"
                $temp
            }
            else {
                $null
            }
        }
    }
    $resourceSelectorsTransform = @{
        label      = "resourceSelectors"
        expression = {
            if ($_.resourceSelectors) {
                (ConvertTo-Json $_.resourceSelectors -Depth 100 -Compress).ToString()
            }
            else {
                ''
            }
        }
    }
    $expiresInDaysTransform = @{
        label      = "expiresInDays"
        expression = {
            if ($_.expiresInDays -eq [Int32]::MaxValue) {
                'n/a'
            }
            else {
                $_.expiresInDays
            }
        }
    }
    $assignmentScopeValidationTransform = @{
        label      = "assignmentScopeValidation"
        expression = {
            if ($_.assignmentScopeValidation) {
                $_.assignmentScopeValidation
            }
            else {
                ''
            }
        }
    }

    #endregion Transformations

    Write-Information ""
    $selectedExemptions = $Exemptions.Values
    $numberOfExemptions = $selectedExemptions.Count
    if ($ActiveExemptionsOnly) {

        #region Active Exemptions

        $stem = "$outputPath/active-exemptions"
        Write-ModernSection -Title "Active Exemptions" -Color Green
        Write-ModernStatus -Message "Environment: $pacSelector" -Status "info" -Indent 2
        Write-ModernStatus -Message "Outputting $numberOfExemptions active exemptions (not expired or orphaned)" -Status "success" -Indent 2
        if ($OutputJson) {
            $selectedArray = $selectedExemptions | Where-Object status -in @("active", "active-expiring-within-15-days") | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                scope, `
                policyAssignmentId, `
                policyDefinitionReferenceIds, `
                resourceSelectors, `
                $metadataTransformJson, `
                assignmentScopeValidation
            $jsonArray = @()
            if ($selectedArray -and $selectedArray.Count -gt 0) {
                $jsonArray += $selectedArray
            }
            # Logic to force the order of the Metadata property (DeployedBy first, then epacMetadata)
            foreach ($array in $jsonArray) {
                if ($null -ne $array.Metadata) {
                    $meta = $array.Metadata
                    $orderedMeta = [ordered]@{
                        deployedBy   = $meta['deployedBy']
                        epacMetadata = $meta['epacMetadata']
                    }
                    $array.Metadata = $orderedMeta
                }
                # Logic to order resourceSelectors
                if ($null -ne $array.resourceSelectors) {         
                    $array.resourceSelectors = $array.resourceSelectors | ForEach-Object {
                        [PSCustomObject]@{
                            name      = $_.name
                            selectors = ($_.selectors | ForEach-Object {
                                    $obj = [ordered]@{ kind = $_.kind }
                                    if ($_.in) { $obj["in"] = $_.in }
                                    if ($_.notIn) { $obj["notIn"] = $_.notIn }
                                    [PSCustomObject]$obj
                                })
                        }
                    }
                }
            }
            $jsonFile = "$stem.$FileExtension"
            if (Test-Path $jsonFile) {
                Remove-Item $jsonFile
            }
            $outputJsonObj = [ordered]@{
                '$schema'  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-exemption-schema.json"
                exemptions = $jsonArray
            }
            ConvertTo-Json $outputJsonObj -Depth 100 | Out-File $jsonFile -Force
        }
        if ($OutputCsv) {
            $selectedArray = $selectedExemptions | Where-Object status -in @("active", "active-expiring-within-15-days") | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                scope, `
                policyAssignmentId, `
                $policyDefinitionReferenceIdsTransform, `
                $resourceSelectorsTransform, `
                $metadataTransformCsv, `
                $assignmentScopeValidationTransform
            $excelArray = @()
            if ($null -ne $selectedArray -and $selectedArray.Count -gt 0) {
                $excelArray += $selectedArray
            }
            # Logic to force the order of the Metadata property (DeployedBy first, then epacMetadata)
            foreach ($array in $excelArray) {
                if ($null -ne $array.Metadata) {
                    $metaString = $array.Metadata
                    $meta = $metaString | ConvertFrom-Json -Depth 100
                    $orderedMeta = [ordered]@{
                        deployedBy   = $meta.deployedBy
                        epacMetadata = $meta.epacMetadata
                    }
                    $orderedMetadata = (ConvertTo-Json $orderedMeta -Depth 100 -Compress).ToString()
                    $array.Metadata = $orderedMetadata
                }
                # Logic to order resourceSelectors
                if ($null -ne $array.resourceSelectors) {  
                    $tempResourceSelectors = $array.resourceSelectors | ConvertFrom-Json -Depth 100       
                    $tempResourceSelectors = $tempResourceSelectors | ForEach-Object {
                        [PSCustomObject]@{
                            name      = $_.name
                            selectors = ($_.selectors | ForEach-Object {
                                    $obj = [ordered]@{ kind = $_.kind }
                                    if ($_.in) { $obj["in"] = $_.in }
                                    if ($_.notIn) { $obj["notIn"] = $_.notIn }
                                    [PSCustomObject]$obj
                                })
                        }
                    }
                    $array.resourceSelectors = (ConvertTo-Json $tempResourceSelectors -Depth 100 -Compress).ToString()
                }
            }
            $csvFile = "$stem.csv"
            if (Test-Path $csvFile) {
                Remove-Item $csvFile
            }
            if ($excelArray.Count -gt 0) {
                $excelArray | ConvertTo-Csv -UseQuotes AsNeeded | Out-File $csvFile -Force
            }
            else {
                $columnHeaders = "name,displayName,description,exemptionCategory,expiresOn,scope,policyAssignmentId,policyDefinitionReferenceIds,metadata,assignmentScopeValidation"
                $columnHeaders | Out-File $csvFile -Force
            }
        }

        #endregion Active Exemptions

    }
    else {

        #region All Exemptions

        $stem = "$outputPath/all-exemptions"
        Write-ModernSection -Title "All Exemptions" -Color Yellow
        Write-ModernStatus -Message "Environment: $pacSelector" -Status "info" -Indent 2
        Write-ModernStatus -Message "Outputting $numberOfExemptions exemptions (all statuses)" -Status "success" -Indent 2
        if ($OutputJson) {
            $selectedArray = $selectedExemptions | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                status, `
                $expiresInDaysTransform, `
                scope, `
                policyAssignmentId, `
                policyDefinitionReferenceIds, `
                resourceSelectors, `
                $metadataTransformJson, `
                assignmentScopeValidation
            $jsonArray = @()
            if ($selectedArray -and $selectedArray.Count -gt 0) {
                $jsonArray += $selectedArray
            }
            # Logic to force the order of the Metadata property (DeployedBy first, then epacMetadata)
            foreach ($array in $jsonArray) {
                if ($null -ne $array.Metadata) {
                    $meta = $array.Metadata
                    $orderedMeta = [ordered]@{
                        deployedBy   = $meta['deployedBy']
                        epacMetadata = $meta['epacMetadata']
                    }
                    $array.Metadata = $orderedMeta
                }
                # Logic to order resourceSelectors
                if ($null -ne $array.resourceSelectors) {         
                    $array.resourceSelectors = $array.resourceSelectors | ForEach-Object {
                        [PSCustomObject]@{
                            name      = $_.name
                            selectors = ($_.selectors | ForEach-Object {
                                    $obj = [ordered]@{ kind = $_.kind }
                                    if ($_.in) { $obj["in"] = $_.in }
                                    if ($_.notIn) { $obj["notIn"] = $_.notIn }
                                    [PSCustomObject]$obj
                                })
                        }
                    }
                }
            }
            $jsonFile = "$stem.$FileExtension"
            if (Test-Path $jsonFile) {
                Remove-Item $jsonFile
            }
            $outputJsonObj = [ordered]@{
                '$schema'  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-exemption-schema.json"
                exemptions = $jsonArray
            }
            ConvertTo-Json $outputJsonObj -Depth 100 | Out-File $jsonFile -Force
        }
        if ($OutputCsv) {
            $selectedArray = $selectedExemptions | Select-Object -Property name, `
                displayName, `
                description, `
                exemptionCategory, `
                expiresOn, `
                status, `
                $expiresInDaysTransform, `
                scope, `
                policyAssignmentId, `
                $policyDefinitionReferenceIdsTransform, `
                $resourceSelectorsTransform, `
                $metadataTransformCsv, `
                $assignmentScopeValidationTransform
            $excelArray = @()
            if ($null -ne $selectedArray -and $selectedArray.Count -gt 0) {
                $excelArray += $selectedArray
            }
            # Logic to force the order of the Metadata property (DeployedBy first, then epacMetadata)
            foreach ($array in $excelArray) {
                if ($null -ne $array.Metadata) {
                    $metaString = $array.Metadata
                    $meta = $metaString | ConvertFrom-Json -Depth 100
                    $orderedMeta = [ordered]@{
                        deployedBy   = $meta.deployedBy
                        epacMetadata = $meta.epacMetadata
                    }
                    $orderedMetadata = (ConvertTo-Json $orderedMeta -Depth 100 -Compress).ToString()
                    $array.Metadata = $orderedMetadata
                }
                # Logic to order resourceSelectors
                if ($null -ne $array.resourceSelectors) {  
                    $tempResourceSelectors = $array.resourceSelectors | ConvertFrom-Json -Depth 100       
                    $tempResourceSelectors = $tempResourceSelectors | ForEach-Object {
                        [PSCustomObject]@{
                            name      = $_.name
                            selectors = ($_.selectors | ForEach-Object {
                                    $obj = [ordered]@{ kind = $_.kind }
                                    if ($_.in) { $obj["in"] = $_.in }
                                    if ($_.notIn) { $obj["notIn"] = $_.notIn }
                                    [PSCustomObject]$obj
                                })
                        }
                    }
                    $array.resourceSelectors = (ConvertTo-Json $tempResourceSelectors -Depth 100 -Compress).ToString()
                }
            }
            $csvFile = "$stem.csv"
            if (Test-Path $csvFile) {
                Remove-Item $csvFile
            }
            if ($excelArray.Count -gt 0) {
                $excelArray | ConvertTo-Csv -UseQuotes AsNeeded | Out-File $csvFile -Force
            }
            else {
                $columnHeaders = "name,displayName,description,exemptionCategory,expiresOn,status,expiresInDays,scope,policyAssignmentId,policyDefinitionReferenceIds,metadata,assignmentScopeValidation"
                $columnHeaders | Out-File $csvFile -Force
            }

        }

        #endregion All Exemptions

    }

    if ($ExportForEpac) {

        #region EPAC-ready Exemptions Export

        $epacStem = "$outputPath/epac-exemptions"
        Write-ModernSection -Title "EPAC-ready Exemptions" -Color Cyan
        Write-ModernStatus -Message "Environment: $pacSelector" -Status "info" -Indent 2

        # Allowed top-level properties per Schemas/policy-exemption-schema.json.
        # Built dynamically from the input so we only include properties that have meaningful values
        # (the EPAC schema sets additionalProperties: false and also requires certain combinations).
        $epacOptionalProperties = @(
            "displayName",
            "description",
            "exemptionCategory",
            "expiresOn",
            "scope",
            "policyAssignmentId",
            "policyDefinitionReferenceIds",
            "resourceSelectors",
            "assignmentScopeValidation"
        )

        $epacArray = [System.Collections.Generic.List[object]]::new()
        $epacSource = $selectedExemptions
        if ($ActiveExemptionsOnly) {
            $epacSource = $selectedExemptions | Where-Object status -in @("active", "active-expiring-within-15-days")
        }
        foreach ($exemption in $epacSource) {
            $epacObj = [ordered]@{
                name = $exemption.name
            }
            foreach ($prop in $epacOptionalProperties) {
                $value = $exemption.$prop
                if ($null -eq $value) {
                    continue
                }
                if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
                    continue
                }
                if ($value -is [System.Collections.ICollection] -and $value.Count -eq 0) {
                    continue
                }
                if ($prop -eq "resourceSelectors") {
                    $rebuilt = [System.Collections.Generic.List[object]]::new()
                    foreach ($rs in $value) {
                        $selList = [System.Collections.Generic.List[object]]::new()
                        foreach ($sel in $rs.selectors) {
                            $selObj = [ordered]@{ kind = $sel.kind }
                            if ($sel.in) {
                                $inList = [System.Collections.Generic.List[object]]::new()
                                foreach ($v in $sel.in) { $inList.Add($v) }
                                $selObj["in"] = $inList
                            }
                            if ($sel.notIn) {
                                $notInList = [System.Collections.Generic.List[object]]::new()
                                foreach ($v in $sel.notIn) { $notInList.Add($v) }
                                $selObj["notIn"] = $notInList
                            }
                            $selList.Add([PSCustomObject]$selObj)
                        }
                        $rebuilt.Add([PSCustomObject]@{
                                name      = $rs.name
                                selectors = $selList
                            })
                    }
                    $epacObj[$prop] = $rebuilt
                    continue
                }
                if ($prop -eq "policyDefinitionReferenceIds") {
                    $refList = [System.Collections.Generic.List[object]]::new()
                    foreach ($r in $value) { $refList.Add($r) }
                    $epacObj[$prop] = $refList
                    continue
                }
                $epacObj[$prop] = $value
            }

            # Strip Azure-only and EPAC-internal metadata; omit metadata entirely if nothing remains.
            if ($null -ne $exemption.metadata) {
                $cleanMetadata = Get-CustomMetadata -Metadata $exemption.metadata -Remove "pacOwnerId"
                $cleanMetadataHash = ConvertTo-HashTable $cleanMetadata
                foreach ($strip in @("deployedBy", "epacMetadata")) {
                    if ($cleanMetadataHash.Keys -contains $strip) {
                        $cleanMetadataHash.Remove($strip)
                    }
                }
                if ($cleanMetadataHash.Count -gt 0) {
                    $epacObj["metadata"] = $cleanMetadataHash
                }
            }

            $epacArray.Add([PSCustomObject]$epacObj)
        }

        Write-ModernStatus -Message "Outputting $($epacArray.Count) EPAC-ready exemptions" -Status "success" -Indent 2

        $epacFile = "$epacStem.$FileExtension"
        if (Test-Path $epacFile) {
            Remove-Item $epacFile
        }
        $epacOutputObj = [ordered]@{
            '$schema'  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-exemption-schema.json"
            exemptions = $epacArray
        }
        ConvertTo-Json $epacOutputObj -Depth 100 | Out-File $epacFile -Force

        #endregion EPAC-ready Exemptions Export

    }
}
