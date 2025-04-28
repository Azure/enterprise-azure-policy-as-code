# Remediation Procedures

There are two scenarios that are common in Cloud Remediation.

1. Updating Security Posture for New Security Requirements
2. Enforcing Security Posture for Steady State Operations

The first is the revolutionary change that occurs during the implementation of a new standard, or simply enforcing those that have existed with greater diligence. The second is maintaining the steady state that the environment enters once the former tasks are complete.

## Deploy Remediation Capable Policy Assignments

There are several different ways that policies that affect change can be deployed, and each can be useful depending on the situation. These policies can be identified by the presence of certain [Effect values](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/effect-basics) in their available options. Those policyDefinitions that contain an option (or static requirement) to use the Modify, Append, DeployIfNotExists, or Modify Effects all are capable of affecting change on an object in Azure.

1. Use of the *DoNotEnforce* setting will override **all** policyEffects to Disabled
    1. Allows use of Remediation Tasks for the policyAssignment even though it is disabled
    1. Considerations:
        1. Much faster, requiring little planning
        1. Will not update new deployments, but allows remediation of existing deployments as approval is receieved
        1. New-AzRemediationTask **will** enforce policyAssignments with the *DoNotEnforce* configuration, and it is recommended that these be removed or set to default enforcement before that pipeline is enabled
1. Use of Effect *Override* functionality
    1. Override can be set to any Effect that is supported by that policy
    1. When overriding a policySet, the policyDefinitionReferenceId will be used to identify which policies recieve audit vs auditIfNotExist effect if both exist
    1. If no effects are available, an override to *audit* was accepted in all tested cases
    1. Considerations:
        1. Much more granular control, requiring review of available effects and generating a list of overrides
        1. Provides compliance data
        1. Remediation tasks can be executed in this configuration
        1. New-AzRemediationTask **will** enforce policyAssignments with the *Override* configuration, and it is recommended that the override be removed, and actual effect parameters be used, before that pipeline is enabled

## Updating Security Posture

The objective during this process is to reach a new, more secure, steady state. To achieve this, incremental change is generally preferred as testing workloads in the new security framework can be time consuming, and rollbacks should be avoided whenever possible. This is not the time to implement a pipeline that will update the entire environment at once as this tends to cause operational challenges, and instead workloads should be targeted for prioritized changes at a pace that can be managed by the local teams.

The EPAC cmdlet New-AzRemediationTask is written to leverage the EPAC system to automate enforcement of as many as all of the policyAssignments that exist in EPAC in a single line of code. While this is extremely powerful, it is intended to be automation that leverages the native [Start-AzPolicyRemediation](https://learn.microsoft.com/en-us/powershell/module/az.policyinsights/start-azpolicyremediation) cmdlet at Enterprise Scale. If this scale is not desired, it is recommended to simply use the Start-AzPolicyRemediation cmdlet from the [Az](https://www.powershellgallery.com/packages/Az).PolicyInsights module to accomplish this goal until a steady state can be reached for a given assignment, which should at that time be transitioned to the Steady State procedure below.

While this does not take advantage of EPAC's global-settings files to auto-complete many of the fields, it does offer options to reduce the scope that are appealing at this point in the process. As an alternative, if you wish to leverage EPAC, consider a ***temporary*** pacSelector in the global-settings file at the scope that you wish to affect. This can leverage remediation deployments at a scope without affecting the rest of your CI/CD process.

### Baseline Update Workflow

While all processes should be optimized for the organization, a basic workflow that conforms to Cloud Maturity Model (CMM) 3 standards has been provided below. It is necessary to remain at this level until this is complete as manual effort within a defined framework is the standard for this stage. While it is possible to skip straight to CMM 5 enforcement, this is likely to cause outages without a clear understanding of every scope. In most cases, this is not available at this stage. Completion of this effort will enable enforcement approaches that conform to CMM 5 standards by introducing proactive maintenance.

1. Deploy an Audit standard
    1. This is generally Microsoft Cloud Security Baseline and one or two other global, compliance, or regulatory standards
    1. Use a single assignment file to minimize duplication of effort in parameter configuration, there will generally be significant overlap in these policySets
    1. Update the environment specific parameters that will be enforced, but the Effect settings can be ignored for now
    1. Set `enforcementMode: 'DoNotEnforce'` for the Assignment
1. Deploy ALZ
    1. ALZ includes a plethora of corrective (DeployIfNotExist/Modify/Append/etc.) policyDefinitions that can be used to help bring an environment up to the MCSB (etc.) standards
    1. Update the environment specific parameters that will be enforced, but the Effect settings can be ignored for now
    1. Set `enforcementMode: 'DoNotEnforce'` for the Assignments
1. Initiate Steady State Preparation Workstreams:
    1. Use Start-AzPolicyRemediation to update the environment incrementally to reach the desired security posture
    1. Review and update Effect parameters from Default values where desired on these policyAssignments

## Enforcing Security Posture

When this is enabled, Azure Resource Manager Configuration is being managed at or near CMM 5, provided all Tenants are accessible by the automation tools as this level of federation is a prerequisite to this status.

The objective at this point is to reduce the administration teams' effort to correct deployments that do not meet security standards outlined by the company by maintaining the configuration proactively, which is to say without prompting from human administrators to do so. While this *can* be a manual task, the EPAC CI/CD Pipeline for Remediation provided in the StarterKit should be leveraged for this in order to reduce the effort of the administration team.

While Infrastructure as Code is an excellent first layer, the second layer in a Defense In Depth model is to enforce this. In Azure Resource Manager, we use Azure Policy Remediation Tasks to accomplish this. Whereas Start-AzPolicyRemediation does allow very targetted deployments, EPAC seeks to take corrective action in broad swaths using the security structure that has been implemented. To this end, the cmdlet New-AzRemediationTasks was created, and can be used in a pipeline to remediate all policyAssignments (that have that capability) in a single pipeline action that should be scheduled with a cron trigger.

Once the *Updating Security Posture* Workstreams above are complete, it is time to move on into the upper tiers of CMM for ARM Governance, congratulations! The environment will be largely self-correcting after this is compelte.

1. Change `enforcementMode: 'DoNotEnforce'` to `enforcementMode: 'Default'` where applicable
1. Ensure `DesireStateConfiguration: 'full'` is configured
1. Confirm the compliance items remaining are acceptable to change at this time
1. Enable the EPAC Deployment Pipeline on a cron schedule to enforce policy configuration
1. Enable the EPAC Remediation Pipeline on a cron schedule to enforce ARM configurations managed by policy
    1. This will require some customization
    1. Review the compliance information for these policyAssignments prior to running this for the first time to understand the scope of change that will be introduced

 > NOTE
 > This will consume CPU time during each run, even when it is simply determining there is no need to apply any changes. If you are running on a free tier, using a cloud hosted SaaS Runner, you may wish to consider either transitioning to a plan with more compute minutes, or a self-hosted runner, before undertaking this action.
