# Quick start guide

To onboard the solution to your customer's environment, follow the below steps:
> **Prerequisites:**
> - Build a management group dedicated to Policy as Code (PaC)
> - Create two subscriptions under the PaC management group
> -- Recommended naming:
>      + PaC-Dev
>      + PaC-QA

## Getting Started
1. Create an Azure DevOps project dedicated to Policy as Code (PaC)
   - You may also create a dedicated PaC repo within an existing Azure DevOps project
   
2. Import this repository into the newly created PaC repository:
   - https://docs.microsoft.com/en-us/azure/devops/repos/git/import-git-repository?view=azure-devops

3. Create the Service Connections in Azure DevOps with the required permissions:
   - Create an AAD Service Principal (SPN). A service connection is required for each environment that Azure Policy will be deployed and assigned.
   - The suggested:
      + Prod - Parent Management Group (`Resource Policy Contributor` and `User role administrator` at parent management group level)
      + QA - Sandbox Subscription to be used for testing and verification (`Resource Policy Contributor` at parent management group level and `Owner` at the subscription level)
      + Dev - Sandbox Subscription for policy development (`Resource Policy Contributor` at parent management group level and `Owner` at the subscription level)

   - NOTE: you may assign a custom role definition: policy reader role at the parent management group level for Dev and QA. Both service connections need the ability to read policy information over the entire environment
      + **Policy Reader role**
      + `Microsoft.Authorization/policyAssignments/read`
      + `Microsoft.Authorization/policyDefinitions/read`
      + `Microsoft.Authorization/policySetDefinitions/read`
   - Grant the required permissions to this SPN in Azure. Note that depending on your scenario, these permissions may be very high. If you're planning to use DeployIfNotExists (DINE) policies, the SPN has to have owner rights on the scope of the assignment, so that it can grant access to the generated system assigned identity at deployment time. With other words, you may need Owner permission on Tenant Root group level to fully unlock all the capabilities of Azure policies and this solution.
      + The SPN will also need `Azure Active Directory reader` role. This is required both for the permission pre-flight check and for assigning permissions (for DeployIfNotExists policies) as the role assignment PowerShell commandlet requires this permission.
      + Register the SPN in ADO as a Service Connection.
   -  The number of service connections is equal to 2 plus the number of tenants
   -  https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#sep-azure-resource-manager
   
4. Configure the deployment pipeline
   - Register the pipeline (pipeline.yml in the `Pipeline` folder of the repository).
   - Modify the pipeline to include the service connections and desired scope for your policy deployments (See the **[pipeline documentation](./docs/Pipeline.md)** file for more details on this)
   - The pipeline is triggered in various ways depending on the scope you are ready to deploy to. See the **[pipeline documentation](./docs/Pipeline.md)** to find a more detailed explanation on how each stage of the pipeline is triggered.

5. Create environments in Azure DevOps
    - Environments must be created to isolate deployment controls and set approval gates
    - Create the following three environments (case sensitive):
        + SCaC-PROD
        + SCaC-QA
        + SCaC-DEV
    - If you would like to modify the names of these environments, you must also modify the pipeline environments for each stage in the pipeline file (**[pipeline.yml](./pipeline/Pipeline.yml)**)

6. Create policies, initiatives, and assignments as needed
   - **NOTE: if you are NOT using a greenfield environment, you must add the suppress delete operator to the pipeline file to keep previous policies, initiatives, and assignments**
      + This must be done in all of the stages where the `Build-AzPoliciesInitiativesAssignmentsPlan.ps1` script is used.
      + `-suppressDeletes` must be added as an argument in every stage or else the script will delete unnecessary policy items.
```json
scriptPath: "Scripts/Deploy/Build-AzPoliciesInitiativesAssignmentsPlan.ps1"
                    arguments: -TenantId $(tenantId) `
                      -AssignmentSelector $(devAssignmentSelector) `
                      -RootScope $(devRootScope) `
                      -PlanFile $(devPlanFile) `
                      -InformationAction Continue `
                      -suppressdeletes
```
   - Follow the included file structures
   - Trigger the pipeline to deploy to each envrionment with these actionss:
      + DEV - Commit to feature branch or manually trigger
      + QA - Pull request is approved
      + Prod - Azure DevOps approval gate is completed
**Single Tenant Policy as Code Overview**
>![image.png](./Docs/images/SingleTenantOverview.png)

**Multi Tenant Policy as Code Overview**
>![image.png](./Docs/images/MultiTenantOverview.png)

## Azure Security Modernization

This repo has been developed in partnership with the Azure Security Modernization (ASM) offering within Microsoft Consulting Services (MCS)

ASM improves your new or existing security posture in Azure by securing platforms, services, and workloads at any scale. ASM revolves around a continuous security improvement model (Measure, Plan, Develop & Deliver) giving visibility into security vulnerabilities.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

## Next steps
Read through the rest of the documentation and configure the pipeline to your needs.

- **[Definitions](./Docs/Definitions.md)**
- **[Assignments](./Docs/Assignments.md)**
- **[Scripts and Configuration Files](./Docs/ScriptsAndConfigurationFiles.md)**
- **[Pipeline](./Docs/pipeline.md)**

[Return to the main page.](../readme.md)
