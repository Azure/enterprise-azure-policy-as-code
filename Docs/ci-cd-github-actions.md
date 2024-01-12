# Github Actions

The starter kit contains a sample pipeline to use GitHub Actions to deploy Enterprise Policy as Code. It features a review process and is driven by pull requests and approvals.

We have revised our approach to GitHub Actions simplifying the process and make it easier to understand. The new approach is documented below and is included in the starter kit with v8.5 and later.

The previous version is still available in the starter kit in folder `Legacy` and the [documentation is retained](#previous-cicd-workflow----legacy) after the documentation for the new approach.

## Setup in GitHub

### Create GitHub Deployment Environments

You will need one [GitHub deployment environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) for the `epac-dev` workflow and three environments each for your epac-prod or tenant workflows. This documentation assumes the include starter kit pipelines.

| Environment | Purpose | [App Registration](./ci-cd-app-registrations.md) (SPN) |
|---|---|---|
| EPAC-DEV | Plan and deploy to `epac-dev` | ci-cd-epac-dev-owner |
| TENANT-PLAN | Build deployment plan for `tenant` | ci-cd-root-policy-reader |
| TENANT-DEPLOY-POLICY | Deploy Policy resources for `tenant` | ci-cd-root-policy-contributor |
| TENANT-DEPLOY-ROLES | Deploy Roles for `tenant` | ci-cd-root-user-assignments |

For each environment, [add to the environment secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-secrets) for the tenant id, client id and client secret for the SPN. The secrets must be named `TENANT_ID`, `CLIENT_ID` and `CLIENT_SECRET` respectively.

### Hardening each Environment

* Global setting for the repo: protect the `main` branch with [branch protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).
* [Configure required reviewers](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#required-reviewers) for TENANT-DEPLOY-POLICY and TENANT-DEPLOY-ROLES environments.
* [Restrict branch](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#deployment-branches-and-tags) to `main` branch for TENANT-DEPLOY-POLICY and TENANT-DEPLOY-ROLES environments.
* Do not [allow administrators to bypass configured protection rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#allow-administrators-to-bypass-configured-protection-rules) for TENANT-DEPLOY-POLICY and TENANT-DEPLOY-ROLES environments.

## New GitHub Workflows

Each of the workflows has three (3) jobs:
* `Build` - Builds the deployment plan
* `Deploy Policy` - Deploys the policy plan
* `Deploy Roles` - Deploys the role plan

The starter kit contains the following workflows:

* `epac-dev.yaml` is the workflow for the `epac-dev` environment. It is triggered on push to any `feature/**` branch.
* `tenant.yaml` is the workflow for the `epac-prod` or `tenant` environments. It is triggered on PR closed to the `main` branch.

## Testing your Workflows

To test the actions make a change to a file in the definitions folder.

## Previous CI/CD Workflow -- Legacy

This section is retained from the previous documentation to enable you to continue using the previous approach. It is recommended that you migrate to the new approach as soon as possible.

### Action Flow -- Legacy

1. Changes are made to files in the Definitions folder (e.g. new policy definition/assignment, removing files) and pushed to GitHub
2. The `Build Deployment Plan` action is triggered. This runs the `Build-DeploymentPlans` function against the environment specified in the `pacEnvironment` variable in `global-settings.jsonc`
3. If there are changes detected the plan is committed to a new branch and a pull request is created. A label of `PolicyDeployment` is attached and a reviewer is added.
4. At this stage you can browse the plan created by the action before approving. It is important to not merge this branch as it will remove the `.gitignore` file from the base branch and will cause the `Output` folder to be permanently committed to the project.
5. If the changes are ready to be deployed - the pull request must be approved.
6. The approval action will start the `Deploy Policy Plan and Roles` workflow.
7. The policy plan will be deployed using `Deploy-RolesPlan`. When this is complete one of two things can happen.
    * If there are no role changes to be processed the PR is closed (not merged) and the branch containing the plan is deleted. (End of process)
    * If there are role changes a label of `RoleDeployment` is added - and the reviewer is removed and re-added. This triggers another review on the pipeline which must be approved before role changes are deployed.
8. For role changes when the PR is approved again the same action runs - this time using the `Deploy-RolesPlan` for deployment.
9. When complete the PR is closed and the branch containing the plan is deleted.

!!! note
    This is a sample method of deploying policy and role changes - feel free to modify it to suit your environment and contribute to this project if you want to share an update.

### Setup in GitHub -- Legacy

There are some steps to be performed in GitHub to ensure the action runs correctly.

1. Create two labels in the project called `PolicyDeployment` and `RoleDeployment`. Instructions to create new labels are [here](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels#creating-a-label).
2. Create secrets representing an SPN in GitHub for the repository as below - these are used to authenticate to Azure

    | Secret Name | Value |
    |---|---|
    | CLIENT_ID | Application ID for SPN |
    | CLIENT_SECRET | Client secret |
    | TENANT_ID | Azure AD Tenant |
    | SUBSCRIPTION_ID | Any subscription ID. Used to login but not in the process |

3. In the `.github\workflows\build.yaml` and `.github\workflows\deploy.yaml` file updated the `env:` section as below.

    | Environment Variable Name | Value | Notes |
    |---|---|---|
    | REVIEWER | Add a GitHub user to review the PR |
    | definitionsRootFolder | The folder containing `global-settings.jsonc` and definitions |
    | pacEnvironment | The policy as code environment specified in `global-settings.jsonc` |
    | planFolder | A folder that plans will be saved to and deployed from | Must be the same folder in `deploy.yaml` |

4. In the `.github\workflows\build.yaml` and `.github\workflows\deploy.yaml` file updated the trigger's path setting to ensure it is triggered when a file change is made.

### Skipping a Workflow Run -- Legacy

To skip the workflow run add a file called `NO_ACTIONS` in the definitions folder. An action will be started on push however the build will not occur.

### Generating Build Results Only -- Legacy

If you want to run just the `Build-DeploymentPlans` but not save the output - add a file called `NO_DEPLOY`. This will run the build step and then cancel the action. You can review the summary output by checking the logs in the cancelled action.
