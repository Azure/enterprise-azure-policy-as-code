# Updating Exemptions

Exemptions are updated frequently as they are a method of preventing enforcement of policy on a scope while requiring review, should an expiration be set. This is generally desirable, and is well received during an audit process.

## Decision: JSON or CSV

In the past, CSV has been the preferred tool in EPAC. However, the introduction of [new ways to apply exemptions](./policy-exemptions.md) has caused a shift in recommendation to JSON. Regardless, the cmdlets provided will continue to output both to empower the consumer to leverage whichever format is preferred.

## Updating exemptions manually

There are some use cases for manual update of the exemptions file. Generally, it is a consideration of what will be less effort to complete.

### Expiration Update

Rather than update and export, an update to the date field can be accomplished with nominal effort.

#### Manual Date Update

1. Browse to policyExemptions/[pacSelectorName] directory
1. Open the json/jsonc/csv file used to manage Exemptions
1. Update Content
    1. Search for the policyAssignmentId, including the full assignment path
        1. Example: ```"policyAssignmentId": "/providers/Microsoft.Management/managementGroups/[ManagementGroupName]/providers/Microsoft.Authorization/policyAssignments/[PolicyAssignmentName]"```
    1. Modify the ```expiresOn``` field within the related block with the new timestamp
        1. Format: "YYYY-MM-DDTmm:hh:ssZ"
        1. Example: "2025-01-01T01:00:00Z"

### Assignment Relocation

Altering the target assignment is necessary if assignments are being moved during the initial onboarding process. For instance, moving assignments from the Tenant Root to the Tenant Intermediate Root. However, doing so will require transitioning all of the Exemptions rapidly to avoid a change in behavior.

In these cases, find each listing for affected assignments in the CSV/JSON file, and duplicate, then update, the reference to reflect the new assignment location. Doing so will allow the exemptions to be applied as the new assignments are applied while retaining the old exemptions until you are ready to remove the assignment entirely.

<!-- #### Manual Assignment Location Updates

> NOTE TODO: REQUIRES TESTING, PURELY CONCEPTUAL

1. Export Current Exemptions for pacSelector
1. Update Content
    1. Replace Root Management Group Name (Tenant GUID) with current assignment location (Tenant Intermediate Root management Group Name):
        1. ```"policyAssignmentId"```
        1. Epac Managed Exemptions: ```metadata\epacMetadata\"policyAssignmentId"```
    1. Replace temporary pacSelector with main pacSelector:
        1. Epac Managed Exemptions: ```metadata\epacMetadata\"pacSelector"```
1. PR to Main branch; this should not change the Exemption that was just added
-->

## Adding/updating exemptions with script

During this process we will export the current Exemptions, and then add additional exemptions to them. The first step is optional as it is not desirable to allow other methods of updating Exemptions after moving to ```desiredState\"strategy":"full"``` configuration.

1. Add new listing

    ```powershell
    $pacSelector = "pacSelectorName"
    $supportId = "SystemName-approvalIdForChange"
    $policyAssignmentId = "/providers/Microsoft.Management/managementGroups/ManagementGroupName/AssignmentName"
    $scope = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/ExcludedResourceGroup/ExcludedResource"
    $name = "Exemption-$supportId"
    $displayName = "Exemption $supportId"
    $description = "EPAC $pacSelector - Exemption documented in $supportId"
    $exemptionCategory = "Waiver|Mitigated"
    $expiresOn = "YYYY-MM-DDTmm:hh:ssZ"

    Set-AzPolicyExemptionEpac -Scope $scope -Name $name -DisplayName $displayName -Description $description -ExemptionCategory $exemptionCategory -ExpiresOn $expiresOn -PolicyAssignmentId $policyAssignmentId
    ```

1. Update Exemptions File
    1. Export New Data
    1. Copy New Data to Definitions Folder

        ```powershell
        $pacSelector = "pacSelectorName"
        $definitionsFolder = "./Definitions"
        $outputFolder = "./Output"
        Get-AzExemptions `
            -PacEnvironmentSelector $pacSelector `
            -DefinitionsRootFolder $definitionsFolder `
            -OutputFolder $outputFolder `
            -FileExtension jsonc `
            -ActiveExemptionsOnly
        Copy-Item `
            $(Join-Path $outputFolder "policyExemptions" $pacSelector "active-exemptions.jsonc") `
            $(Join-Path $definitionsFolder "policyExemptions" $pacSelector "active-exemptions.jsonc") `
            -Force
        ```
