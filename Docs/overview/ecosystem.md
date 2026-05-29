# EPAC Ecosystem

Enterprise Policy-as-Code (EPAC), AzAdvertizer, and Azure Governance Visualizer (AzGovViz) are three distinct open source projects maintained by Microsoft employees. Each addresses different needs in enterprise-scale Azure governance.

## Enterprise Policy-as-Code (EPAC)

[GitHub](https://github.com/Azure/enterprise-azure-policy-as-code)

EPAC provides a CI/CD automation solution for the development, deployment, management, and reporting of Azure Policy at scale. It maintains a policy "desired state" for high assurance in controlled environments and supports policy exemption management. Policy definitions and assignments can be managed via JSON or CSV files.

## AzAdvertizer

[azadvertizer.net](https://www.azadvertizer.net/)

A publicly accessible web service providing continually up-to-date insights on Azure Governance capabilities — built-in policy and initiative definitions, Azure aliases, security and regulatory compliance controls, RBAC built-in role definitions, and Azure resource provider operations.

## Azure Governance Visualizer (AzGovViz)

[GitHub](https://github.com/JulianHayward/Azure-MG-Sub-Governance-Reporting)

An open source visualization and reporting solution for Azure environments. Delivers detailed insights covering tenant management group hierarchies, RBAC assignments, Azure policy assignments, Blueprints, Azure network topology, and more. Listed as a recommended tool in both Microsoft Cloud Adoption Framework (CAF) and Microsoft Well Architected Framework (WAF).

---

These three tools are complementary: AzAdvertizer helps you **discover** what policies exist, EPAC helps you **deploy and manage** them at scale, and AzGovViz helps you **visualize and audit** the resulting governance state.
