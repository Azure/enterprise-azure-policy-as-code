<#
    .SYNOPSIS
        Creates a new change entry object with specified properties. This is not intended to be published, and is for use within the module for logging purposes.

    .DESCRIPTION
        The New-HydrationChangeEntry function creates a new PSObject and adds properties to it: 'File', 'Property', 'OriginalValue', and 'NewValue'. 
        This object represents a change entry, which can be used to track changes in files. This was created to assist with logging output
        from scripts which update the json files used in the repo.

    .PARAMETER Property
        The name of the property that has been changed.

    .PARAMETER OriginalValue
        The original value of the property before the change. This parameter is not mandatory.

    .PARAMETER NewValue
        The new value of the property after the change.

    .PARAMETER fileName
        The name of the file where the change has occurred.

    .EXAMPLE
        New-HydrationChangeEntry -Property "PropertyName" -OriginalValue "OldValue" -NewValue "NewValue" 
        -fileName "C:\MyRepo\Definitions\policyAssignments\MyFirstPolicyAssignment.jsonc"

        This example creates a new change entry for a property named "PropertyName" that changed 
        from "OldValue" to "NewValue" in the file 
        "C:\MyRepo\Definitions\policyAssignments\MyFirstPolicyAssignment.jsonc".

    .LINK
        https://aka.ms/epac
        https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md

    #>
function New-HydrationChangeEntry {
    # TODO: Test new method to make sure the objects are the same

    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Property,
        [Parameter(Mandatory = $false)]
        [string]
        $OriginalValue,
        [Parameter(Mandatory = $true)]
        [string]
        $NewValue,
        [Parameter(Mandatory = $true)]
        [string]
        $FileName
    )
    $changeEntry = [ordered]@{
        file          = $FileName
        property      = $Property
        originalValue = $OriginalValue
        newvalue      = $NewValue
    }
    return $changeEntry
}