![EPAC](Images/epac_banner_thin.svg)

**Enterprise Azure Policy as Code (EPAC)** is a PowerShell-based CI/CD solution for deploying and managing Azure Policy at scale — Policies, Policy Sets, Assignments, Exemptions, and Role Assignments — across single or multi-tenant environments.

> [!CAUTION]
> EPAC is a true desired state deployment technology. It takes possession of all Policy Resources at the `deploymentRootScope` and its children. It will **delete any Policy resources not defined in the EPAC repo**. This behavior can be modified as documented in the [desired state strategy](configuration/desired-state.md) page.

> [!IMPORTANT]
> For the latest release notes and breaking changes, see [Changelog](overview/changelog.md).

## Documentation

| Section | Description |
|---|---|
| [Overview & Concepts](overview/concepts.md) | Core concepts: desired state, pacEnvironments, deployment model |
| [Getting Started](getting-started/README.md) | Prerequisites, install, and guided on-ramp |
| [Configuration](configuration/global-settings.md) | Global settings, desired state, advanced options |
| [Policy Resources](policy-resources/assignments.md) | Definitions, assignments, exemptions |
| [CI/CD](ci-cd/README.md) | Azure DevOps, GitHub Actions, branching flows |
| [Operations](operations/README.md) | Operational scripts reference |
| [Integrations](integrations/alz-overview.md) | Azure Landing Zones integration |
| [Ecosystem](overview/ecosystem.md) | EPAC, AzAdvertizer, and AzGovViz |

## Project Links

- [GitHub Repo](https://github.com/Azure/enterprise-azure-policy-as-code)
- [GitHub Issues](https://github.com/Azure/enterprise-azure-policy-as-code/issues)
- [PowerShell Gallery Module](https://www.powershellgallery.com/packages/EnterprisePolicyAsCode)
- [Starter Kit](https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/StarterKit)
- [YouTube Series](https://www.youtube.com/channel/UCtkZkkgT-mp6PcmvfqlwvBQ)
- [Azure Enterprise Policy as Code – A New Approach](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/azure-enterprise-policy-as-code-a-new-approach/ba-p/3607843)
- [Azure Enterprise Policy as Code – Azure Landing Zones Integration](https://techcommunity.microsoft.com/t5/core-infrastructure-and-security/azure-enterprise-policy-as-code-azure-landing-zones-integration/ba-p/3642784)

## Telemetry

EPAC tracks usage via [Customer Usage Attribution](https://learn.microsoft.com/azure/marketplace/azure-partner-customer-usage-attribution). To opt out, set `telemetryOptOut: true` in `global-settings.jsonc`. See [configuration docs](configuration/global-settings.md#opt-out-of-telemetry-data-collection-telemetryoptout) for details.

## Support & Contributing

Please raise issues via [GitHub Issues](https://github.com/Azure/enterprise-azure-policy-as-code/issues). See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.
