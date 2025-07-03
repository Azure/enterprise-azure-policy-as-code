# Integrating EPAC with Azure Landing Zones

## What are Azure Landing Zones (ALZ)?

Azure Landing Zones (ALZ) are a set of best practices, templates, and resources provided by Microsoft to help organizations set up a secure, scalable, and compliant foundation in Azure. They are part of the broader Cloud Adoption Framework (CAF), which is Microsoft's guidance for cloud adoption across strategy, planning, readiness, governance, and management.

Microsoft publishes and maintains a [list of Policies, Policy Sets and Assignments](https://aka.ms/alz/policies) which are deployed as part of the Cloud Adoption Framework Azure Landing Zones deployment. The central repository that contains these policies acts as the source of truth for ALZ deployments via the portal, Bicep and Terraform.

To enable customers to use the Enterprise Policy as Code solution and combine Microsoft's policy recommendations there is a script which will pull the Policies, Policy Sets and Policy Assignments from the central repository and allow you to deploy them using this solution.

As the policies and assignments change in main repository the base files in this solution can be updated to match.

## Why and when should you use EPAC to manage ALZ deployed policies

EPAC can be used to manage Azure Policy deployed using ALZ Bicep or Terraform using the scenarios below. Some reasons you may want to switch to EPAC policy management include:

- You have existing unmanaged policies in a brownfield environment that you want to deploy in the new ALZ environment. [Export the existing policies](start-extracting-policy-resources.md) and manage them with EPAC alongside the ALZ policy objects.
- You have ALZ deployed in a non standard way e.g. multiple management group structures for testing, non-conventional management group structure. The default assignment structure provided by other ALZ deployment methods may not fit your strategy.
- A team that is not responsible for infrastructure deployment e.g. a security team may want to deploy and manage policies.
- You require features from policy not available in the ALZ deployments e.g. policy exemptions, documentation, assignment customization.
- Non-compliance reporting and remediation task management.

## Scenarios

1. Existing Azure Landing Zones deployment and EPAC is to be used as the policy engine moving forward.
2. Using EPAC to deploy and manage the Azure Landing Zone policies.

In both cases it is now recommended that if you have the default ALZ policies deployed you should use the [new method](integrating-with-alz-library.md) to provide a consistent sync process.