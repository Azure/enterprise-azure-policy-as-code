# Usage Tracking

Starting with v8.0.0, Enterprise Policy as Code (EPAC) is tracking the usage using Customer Usage Attribution (PID).

## Telemetry Tracking Using Customer Usage Attribution (PID)

Microsoft can identify the deployments of the Azure Resource Manager with the deployed Azure resources. Microsoft can correlate these resources used to support the deployments. Microsoft collects this information to provide the best experiences with their products and to operate their business. The telemetry is collected through [customer usage attribution](https://learn.microsoft.com/azure/marketplace/azure-partner-customer-usage-attribution). The data is collected and governed by Microsoft's privacy policies, located at the [trust center](https://www.microsoft.com/trustcenter).

To opt-out of this tracking, we have included a settings in `global-settings.jsonc` called `telemetryOptOut`. If you would like to disable this tracking, then simply [set this value](definitions-and-global-settings.md#opt-out-of-telemetry-data-collection-telemetryoptout) to `true` (default is `false`).

If you are happy with leaving telemetry tracking enabled, no changes are required.

## Module PID Value Mapping

The following is the unique IDs (also known as PIDs) used in each of the modules:

| Function Name | PID |
|:------------|:----|
| `Deploy-PolicyPlan` | `3c88f740-55a8-4a96-9fba-30a81b52151a` |
| `Deploy-PolicyPlan` | `fe9ff1e8-5521-4b9d-ab1d-84e15447565e` |
| `Deploy-RolesPlan` | `cf031290-b7d4-48ef-9ff5-4dcd7bff8c6c` |
| `Build-PolicyDocumentation` | `2dc29bae-2448-4d7f-b911-418421e83900` |
| `Create-AzRemediationTasks` | `6f4dcbef-f6e2-4c29-ba2a-eef748d88157` |
| `Export-AzPolicyResources` | `dc5b73fd-e93c-40ca-8fef-976762d1d30` |
| `Export-NonComplianceReports` | `f464b017-898b-4156-9da5-af932831fa2f` |
| `Get-AzExemptions` | `3f02e7d5-1cf5-490a-a95c-3d49f0673093` |
| `New-AzPolicyReaderRole` | `f4b5b7ac-70b4-40fc-836f-585791aa83e7` |