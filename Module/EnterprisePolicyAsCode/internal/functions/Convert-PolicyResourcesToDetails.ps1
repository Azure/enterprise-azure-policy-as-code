function Convert-PolicyResourcesToDetails {
    [CmdletBinding()]
    param (
        [hashtable] $AllPolicyDefinitions,
        [hashtable] $AllPolicySetDefinitions
    )

    Write-Information "==================================================================================================="
    Write-Information "Pre-calculating parameters for Policy and Policy Set definitions"
    Write-Information "==================================================================================================="

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
        Write-Information "Processing $($AllPolicyDefinitions.psbase.Count) Policy definitions in $throttleLimit parallel threads."
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
        Write-Information "Calculating effect parameters for $($AllPolicyDefinitions.psbase.Count) Policies."
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
        Write-Information "Processing $($AllPolicySetDefinitions.psbase.Count) Policy Set definitions in $throttleLimit parallel threads."
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
        Write-Information "Calculating effect parameters for $($AllPolicySetDefinitions.psbase.Count) Policy Sets."
        foreach ($policySetId in $AllPolicySetDefinitions.Keys) {
            $policySet = $AllPolicySetDefinitions.$policySetId
            Convert-PolicySetToDetails `
                -PolicySetId $policySetId `
                -PolicySetDefinition $policySet `
                -PolicySetDetails $policySetDetails `
                -PolicyDetails $policyDetails
        }
    }
    Write-Information ""

    # Assemble result
    $combinedPolicyDetails = @{
        policies   = $policyDetails
        policySets = $policySetDetails
    }
    return $combinedPolicyDetails
}
