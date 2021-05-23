# Manage Azure Policy Pipelines


## Pre-Deployment Checklist 

This document defines all necessary prerequisites for the implementation of Azure Policy pipelines. Please complete the following checklist prior to delivery.  

### **GitHub Repo Access**
* **Start out by accessing the manage-azure-policy-pipeline repo. This repo contains all of the files you will need to get started.** 
  * https://github.com/Azure/manage-azure-policy-pipeline  


### **Azure DevOps** 
* **Create Azure DevOps Organization** 
  * https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization?view=azure-devops  


* **Create Azure DevOps Project** 
  * https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page  


* **Create Repo: 'Azure Policy'** 
  * https://docs.microsoft.com/en-us/azure/devops/repos/git/create-new-repo?view=azure-devops  


* **Create Branch Policy** 
  * Navigate to Project Settings &rarr; Repositories &rarr; Branch Policies or Repos &rarr; branches &rarr; branch options &rarr; branch policies  
    * https://docs.microsoft.com/en-us/azure/devops/repos/git/branch-policies?view=azure-devops#configure-branch-policies 
    * Require a minimum number of reviewers: 
  * You can select to require a minimum number of reviewers for any changes, to prohibit recent pushers from approving their own changes (this is highly suggested), or when new changes are pushed.  
   * Check for linked work items: 
     * You can check for linked work items to encourage traceability by blocking or warning if there are any linked work items. Depending on which is chosen, this policy will warn but allow pull requests or block pull requests. 
  * Check for comment resolution: 
    * You can check for comment resolution. This will either block or warn pull requests from being completed if any comments are active. 
  * Limit merge types: limit the available types of merge when pull requests are completed. 
    * Basic merge (no-fast forward) 
    * Rebase and fast-forward
    * Squash merge 
    * Rebase with merge commit 
  * Other Branch Policies:  
    * Automatically Include Reviewers:  
    * There is an option to add a new reviewer policy for reviewers to approve or deny pull requests 
    * Add Status Policy: 
      * You can set the status to successful as required or optional to complete a pull request 
    * Add Build Policy: 
      * You can automatically or manually trigger the source branch whenever updated and set build expiration time 
  * After you set up a required branch policy, you cannot directly push changes to the branch. Changes to the branch are only made through pull requests. 


* **Create Azure DevOps Azure RM Service Connection(s)** 
  * A service connection is required for each environment Azure Policy will be deployed and assigned. The suggested: 
  * **Prod** - Tenant Root Group or Parent Management Group 
  * **NonProd** - Sandbox Subscription to be used for testing and verification 
  * **Dev** - Duplicate Sandbox Subscription for policy development 
  * https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml#sep-azure-resource-manager  
  * Azure DevOps Portal &rarr; Project Settings &rarr; Service Connections &rarr; New Service Connection &rarr; Azure Resource Manager &rarr; Service Principal (Automatic) &rarr; Desired Scope Level &rarr; Save 


* **Assign 'Resource Policy Contributor' to the newly assigned service connection(s) created above.** 
  * Click 'Manage Service Principal' on the service connection details page to open AAD and retrieve 'Display name' from ‘Branding’ 
    * You may also change this display name to something of your choice 
  * Go back to the ADO portal and Click 'Manage service connection roles' on the service connection details page to open AAD and add role assignment for ‘Resource Policy Contributor’ to your connection 
  * **Manage service connection roles:** https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal#add-a-role-assignment 


* **Create Policy Pipeline**
  * In the ADO portal, navigate to the pipelines section and create a new pipeline. Select Azure Repos Git and select the Git repository you imported in prior steps. Choose the option to use an existing azure pipelines YAML file. Navigate to the policypipeline.yml file. Save the pipeline. 
  * Edit pipeline to reflect your environment 
    * Replace all service connections fields in the policypipeline.yml with the ADO plaintext name for the connection 
    * You may reference a management group, in this case you will replace the current management group in the pipeline code with the plaintext name of your management group 
      * NOTE: if you are referencing the tenant root group, you will use the ID instead of a plaintext name 
  * Under each stage in the pipeline, there is a reference to the management group name variable. You will make this reference $null if you are not deploying to a management group. Otherwise, make it a reference to the managementGroupName variable. 


* **Create Initiatives Pipeline** 
  * In the ADO portal, navigate to the pipelines section and create a new pipeline. Select Azure Repos Git and select the Git repository you imported in prior steps. Choose the option to use an existing azure pipelines YAML file. Navigate to the initiativepipeline.yml file. Save the pipeline. 
  * Edit pipeline to reflect your environment: 
    * Replace all service connections fields in the initiativepipeline.yml with the ADO plaintext name for the connection 
    * You may reference a management group, in this case you will replace the current management group in the pipeline code with the plaintext name of your management group 
      * NOTE: if you are referencing the tenant root group, you will use the ID instead of a plaintext name 


* **Create Assignment Pipeline** 
  * In the ADO portal, navigate to the pipelines section and create a new pipeline. Select Azure Repos Git and select the Git repository you imported in prior steps. Select existing azure pipelines YAML file. Navigate to the Assignmentpipeline.yml file. Save the pipeline.
  * Edit pipeline to reflect your environment: 
    * Replace all service connections fields in the Assignmentpipeline.yml with the ADO plaintext name for the connection 
    * You may reference a management group, in this case you will replace the current management group in the pipeline code with the plaintext name of your management group 
      * NOTE: if you are referencing the tenant root group, you will use the ID instead of a plaintext name 


* **Create an Approval Gate (Highly Recommended)** 
  * A final approval gate will be used for the last deployment stage into your production environment
  * In the Azure DevOps Portal, navigate to environments and select the production environment that has been created 
    * In each deployment job, there is a parameter called environment, it will go ahead and create an environment in the environments tab in ADO if the environment does not already exist.
  * Select your production environment (SCaC – PROD) and under options select ‘Approvals and Checks’ 
  * Add your custom approval gate depending on your organization’s requirements

* **Deploy to Azure** 
  * Add your policies, initiatives and assignments to their respective folders and make changes as needed 
  * 
  * Policy Deployment Workflow 
    * Create a branch that aligns with your organization’s branching policies 

    * Add or make changes to your policies 

    * Manually run the policy pipeline or create a pull request to deploy to your DEV environment 

    * Upon approval and completion of the pull request, your policy updates will be deployed to your QA environment 

    * Finally, the pull request is subject to an approval gate. Once a member of the team with proper permissions approves the deployment to prod, the pipeline will push your changes to your production environment.  
  * Initiative Deployment Workflow
    * Create a branch that aligns with your organization’s branching policies 

    * Add or make changes to your Initiatives 

    * Manually run the Initiative pipeline or create a pull request to deploy to your DEV environment 

    * Upon approval and completion of the pull request, your initiative updates will be deployed to your QA environment 

    * Finally, the pull request is subject to an approval gate. Once a member of the team with proper permissions approves the deployment to prod, the pipeline will push your changes to your production environment. 
  * Assignment Deployment Workflow
    * Create a branch that aligns with your organization’s branching policies 
    * You may assign policies or assignments at any scope desired. You can also specifiy multiple locations to deploy at (Ex. Deploy one assignment at multiple management groups)

    * Add or make changes to your assignments 
    * Upon approval and completion of the pull request, your assignment updates will be deployed to your environment 
    * https://docs.microsoft.com/en-us/azure/governance/policy/concepts/assignment-structure



   
