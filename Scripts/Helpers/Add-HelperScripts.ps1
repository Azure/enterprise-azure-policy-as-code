#Requires -PSEdition Core

# Load cmdlets
. "$PSScriptRoot/../Helpers/Build-AssignmentDefinitionAtLeaf.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentDefinitionEntry.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentDefinitionNode.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentIdentityChanges.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentParameterObject.ps1"
. "$PSScriptRoot/../Helpers/Build-AssignmentPlan.ps1"

. "$PSScriptRoot/../Helpers/Build-ExemptionsPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-NotScopes.ps1"
. "$PSScriptRoot/../Helpers/Build-PolicyPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-PolicySetPlan.ps1"
. "$PSScriptRoot/../Helpers/Build-PolicySetPolicyDefinitionIds.ps1"

. "$PSScriptRoot/../Helpers/Confirm-ActiveAzExemptions.ps1"
. "$PSScriptRoot/../Helpers/Confirm-AssignmentParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-MetadataMatches.ps1"
. "$PSScriptRoot/../Helpers/Confirm-NullOrEmptyValue.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PacOwner.ps1"
. "$PSScriptRoot/../Helpers/Confirm-DeleteForStrategy.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ObjectValueEqualityDeep.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionsMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionsUsedMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicySetDefinitionUsedExists.ps1"

. "$PSScriptRoot/../Helpers/Convert-EffectToOrdinal.ps1"
. "$PSScriptRoot/../Helpers/Convert-EffectToString.ps1"
. "$PSScriptRoot/../Helpers/Convert-OrdinalToEffectDisplayName.ps1"
. "$PSScriptRoot/../Helpers/Convert-ListToToCsvRow.ps1"
. "$PSScriptRoot/../Helpers/Convert-ParametersToString.ps1"
. "$PSScriptRoot/../Helpers/Convert-PolicySetsToDetails.ps1"
. "$PSScriptRoot/../Helpers/Convert-PolicySetsToFlatList.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-ArrayList.ps1"
. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

. "$PSScriptRoot/../Helpers/Get-AssignmentsDetails.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyResources.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/Get-CustomMetadata.ps1"
. "$PSScriptRoot/../Helpers/Get-DeepClone.ps1"
. "$PSScriptRoot/../Helpers/Get-DefinitionsFullPath.ps1"
. "$PSScriptRoot/../Helpers/Get-DeploymentPlan.ps1"
. "$PSScriptRoot/../Helpers/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Get-HashtableShallowClone"
. "$PSScriptRoot/../Helpers/Get-HashtableWithPropertyNamesRemoved.ps1"
. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-ParameterNameFromValueString.ps1"
. "$PSScriptRoot/../Helpers/Get-PolicyResourceDetails.ps1"
. "$PSScriptRoot/../Helpers/Get-PolicyResourceProperties.ps1"
. "$PSScriptRoot/../Helpers/Get-ScrubbedString.ps1"
. "$PSScriptRoot/../Helpers/Get-SelectedPacValue.ps1"

. "$PSScriptRoot/../Helpers/Merge-AssignmentParametersEx.ps1"
. "$PSScriptRoot/../Helpers/Merge-ExportNodeAncestors.ps1"
. "$PSScriptRoot/../Helpers/Merge-ExportNodeChild.ps1"

. "$PSScriptRoot/../Helpers/New-ExportNode.ps1"

. "$PSScriptRoot/../Helpers/Out-PolicyAssignmentFile.ps1"
. "$PSScriptRoot/../Helpers/Out-PolicyAssignmentDocumentationToFile.ps1"
. "$PSScriptRoot/../Helpers/Out-PolicyDefinition.ps1"
. "$PSScriptRoot/../Helpers/Out-PolicyExemptions.ps1"
. "$PSScriptRoot/../Helpers/Out-PolicySetsDocumentationToFile.ps1"

. "$PSScriptRoot/../Helpers/Remove-NullFields.ps1"
. "$PSScriptRoot/../Helpers/Remove-GlobalNotScopes.ps1"

. "$PSScriptRoot/../Helpers/Search-AzGraphAllItems.ps1"

. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"

. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"
. "$PSScriptRoot/../Helpers/Set-AzPolicyAssignmentRestMethod.ps1"
. "$PSScriptRoot/../Helpers/Set-AzPolicyDefinitionRestMethod.ps1"
. "$PSScriptRoot/../Helpers/Set-AzPolicySetDefinitionRestMethod.ps1"

. "$PSScriptRoot/../Helpers/Set-AssignmentNode.ps1"
. "$PSScriptRoot/../Helpers/Set-ExportNode.ps1"
. "$PSScriptRoot/../Helpers/Set-ExportNodeAncestors.ps1"

. "$PSScriptRoot/../Helpers/Split-AzPolicyResourceId.ps1"
. "$PSScriptRoot/../Helpers/Split-ScopeId.ps1"

. "$PSScriptRoot/../Helpers/Switch-PacEnvironment.ps1"
