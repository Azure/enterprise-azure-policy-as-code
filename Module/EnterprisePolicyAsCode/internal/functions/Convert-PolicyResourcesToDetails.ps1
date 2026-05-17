function Convert-PolicyResourcesToDetails {
    [CmdletBinding()]
    param (
        [hashtable] $AllPolicyDefinitions,
        [hashtable] $AllPolicySetDefinitions
    )

    Write-ModernSection -Title "Pre-calculating Policy Parameters" -Color Blue
    Write-ModernStatus -Message "Processing Policy and Policy Set definitions for effect analysis" -Status "info" -Indent 2

    # Convert Policy Definitions to Details
    $policyDetails = @{}
    $virtualCores = 4
    if ($virtualCores -gt 1) {
        # maybe parallel processing
        $throttleLimit = $virtualCores
        $chunks = Split-HashtableIntoChunks -Table $AllPolicyDefinitions -NumberOfChunks $throttleLimit
        if ($chunks.Count -le 1) {
            $chunks = $null
        }
        else {
            $throttleLimit = $chunks.Count
        }
    }

    if ($null -ne $chunks) {
        # create synchronized hashtables for parallel processing and functions to pass into parallel context
        $syncPolicyDetails = [System.Collections.Hashtable]::Synchronized($policyDetails)
        $funcConvertPolicyToDetails = ${function:Convert-PolicyToDetails}.ToString()
        $funcGetPolicyResourceProperties = ${function:Get-PolicyResourceProperties}.ToString()
        $funcGetParameterNameFromValueString = ${function:Get-ParameterNameFromValueString}.ToString()
        $funcConvertToHashTable = ${function:ConvertTo-HashTable}.ToString()
        
        # loop through each chunk of Policy definitions and process in parallel
        Write-ModernStatus -Message "Processing $($AllPolicyDefinitions.psbase.Count) Policy definitions using $throttleLimit parallel threads" -Status "info" -Indent 2
        $chunks | ForEach-Object -ThrottleLimit $chunks.count -Parallel {
            # import dot sourced functions into context
            if ($null -eq ${function:Get-PolicyResourceProperties}) {
                ${function:Convert-PolicyToDetails} = $using:funcConvertPolicyToDetails
                ${function:Get-PolicyResourceProperties} = $using:funcGetPolicyResourceProperties
                ${function:Get-ParameterNameFromValueString} = $using:funcGetParameterNameFromValueString
                ${function:ConvertTo-HashTable} = $using:funcConvertToHashTable
            }

            # import parameters into context
            $allPolicyDefinitionsLocal = $using:AllPolicyDefinitions
            $syncPolicyDetails = $using:syncPolicyDetails

            foreach ($policyId in $_.Keys) {
                $policy = $AllPolicyDefinitionsLocal.$policyId
                Convert-PolicyToDetails `
                    -PolicyId $policyId `
                    -PolicyDefinition $policy `
                    -PolicyDetails $syncPolicyDetails
            }
        }
    }
    else {
        # non-parallel processing
        Write-ModernStatus -Message "Calculating effect parameters for $($AllPolicyDefinitions.psbase.Count) Policies (single-threaded)" -Status "info" -Indent 2
        foreach ($policyId in $AllPolicyDefinitions.Keys) {
            $policy = $AllPolicyDefinitions.$policyId
            Convert-PolicyToDetails `
                -PolicyId $policyId `
                -PolicyDefinition $policy `
                -PolicyDetails $policyDetails
        }
    }

    # Convert Policy Set Definitions to Details
    $policySetDetails = @{}
    if ($virtualCores -gt 1) {
        # maybe parallel processing
        $throttleLimit = $virtualCores
        $chunks = Split-HashtableIntoChunks -Table $AllPolicySetDefinitions -NumberOfChunks $throttleLimit
        if ($chunks.Count -le 1) {
            $chunks = $null
        }
        else {
            $throttleLimit = $chunks.Count
        }
    }

    if ($null -ne $chunks) {
        # create synchronized hashtables for parallel processing and functions to pass into parallel context
        $syncPolicySetDetails = [System.Collections.Hashtable]::Synchronized($policySetDetails)
        $funcConvertPolicySetToDetails = ${function:Convert-PolicySetToDetails}.ToString()
        $funcGetPolicyResourceProperties = ${function:Get-PolicyResourceProperties}.ToString()
        $funcGetParameterNameFromValueString = ${function:Get-ParameterNameFromValueString}.ToString()
        $funcConvertToHashTable = ${function:ConvertTo-HashTable}.ToString()
        
        # loop through each chunk of Policy definitions and process in parallel
        Write-ModernStatus -Message "Processing $($AllPolicySetDefinitions.psbase.Count) Policy Set definitions using $throttleLimit parallel threads" -Status "info" -Indent 2
        $chunks | ForEach-Object -ThrottleLimit $chunks.count -Parallel {
            # import dot sourced functions into context
            if ($null -eq ${function:Get-PolicyResourceProperties}) {
                ${function:Convert-PolicySetToDetails} = $using:funcConvertPolicySetToDetails
                ${function:Get-PolicyResourceProperties} = $using:funcGetPolicyResourceProperties
                ${function:Get-ParameterNameFromValueString} = $using:funcGetParameterNameFromValueString
                ${function:ConvertTo-HashTable} = $using:funcConvertToHashTable
            }

            # import parameters into context
            $allPolicySetDefinitionsLocal = $using:AllPolicySetDefinitions
            $syncPolicySetDetails = $using:syncPolicySetDetails
            $policyDetails = $using:policyDetails

            foreach ($policySetId in $_.Keys) {
                $policySet = $AllPolicySetDefinitionsLocal.$policySetId
                Convert-PolicySetToDetails `
                    -PolicySetId $policySetId `
                    -PolicySetDefinition $policySet `
                    -PolicySetDetails $syncPolicySetDetails `
                    -PolicyDetails $policyDetails
            }
        }
    }
    else {
        # non-parallel processing
        Write-ModernStatus -Message "Calculating effect parameters for $($AllPolicySetDefinitions.psbase.Count) Policy Sets (single-threaded)" -Status "info" -Indent 2
        foreach ($policySetId in $AllPolicySetDefinitions.Keys) {
            $policySet = $AllPolicySetDefinitions.$policySetId
            Convert-PolicySetToDetails `
                -PolicySetId $policySetId `
                -PolicySetDefinition $policySet `
                -PolicySetDetails $policySetDetails `
                -PolicyDetails $policyDetails
        }
    }

    Write-ModernStatus -Message "Policy parameter pre-calculation complete" -Status "success" -Indent 2

    # Assemble result
    $combinedPolicyDetails = @{
        policies   = $policyDetails
        policySets = $policySetDetails
    }
    return $combinedPolicyDetails
}
