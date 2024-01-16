# Alternate Script Installation cloning the GitHub Repository

Instead of installing `EnterprisePolicyAsCode` from the PowerShell Gallery, you can clone the GitHub repository and use the scripts described below to install the script source code. This is useful, if your organization has overly restrictive policies on installing PowerShell modules from the PowerShell Gallery. It can also be usefule if you want to contribute EPAC source code to the project.

## Setting up your Repo

1. Initial setup
      1. Create `MyForkRepo` as a fork of [GitHub repo](https://github.com/Azure/enterprise-azure-policy-as-code).
      1. Create `MyWorkingRepo`.
            1. **Clone** your forked repo.
            1. Create a new repo from the clone (**do not** fork `MyForkRepo`)
1. Work in `MyWorkingRepo`
      1. While the root folder is not modified as part of the Sync-Repo process, it is recommended that this part of the file structure not be used for storage of any custom material other than new folders.
          1. You may add additional folders, such as a folder for your own operational scripts.
      1. Use only folders `Definitions` and `Pipeline`, except when working on fixes to be contributed back to GitHub.
          1. Review the [`Sync-Repo.ps1`](#sync-repops1) documentation for additional information on the folders which are destroyed and recreated as part of the version upgrade process for additional insight on this topic.

![image](./Images/Sync-Repo.png)

## Syncing latest Version from GitHub repo

1. Fetch changes from GitHub to `MyForkRepo`.
2. Execute [`Sync-Repo.ps1`](#sync-repops1) to copy files from `MyForkRepo` to `MyWorkingRepo` feature branch.
3. PR `MyWorkingRepo` feature branch.

## Contribute to GitHub

1. Execute [`Sync-Repo.ps1`](#sync-repops1) to copy files from `MyWorkingRepo` to `MyForkRepo` feature branch.
    1. **Be sure not to copy internal references within your files during your sync to MyForkRepo.**
2. PR `MyForkRepo` feature branch.
3. PR changes in your fork (`MyForkRepo`) to GitHub.
4. GitHub maintainers will review the PR.

## Sync-Repo.ps1, Sync-FromGH.ps1, Sync-ToGH.ps1

### Sync-Repo.ps1

The repo contains script to synchronize directories in both directions: `Sync-Repo.ps1`. It only works if you do not modify:

* `Docs`, `Scripts`, `Module` and `StarterKit` directories
* `*.md`, `*.ps1`, `*.yml`, and `LICENSE` files in repo root directory

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `SourceDirectory` | Required | Directory with the source (forked repo) |
| `DestinationDirectory` | Required | Directory with the destination (your private repo) |
| `SuppressDeleteFiles` | Optional | Switch parameter to suppress deleting files in `$destinationDirectory` tree |

### Sync-FromGH.ps1 and Sync-ToGH.ps1

Sync-FromGH.ps1 and Sync-ToGH.ps1 are a wrapper around Sync-Repo.ps1 used by the EPAC maintainers to simplify syncing their development repo `epac-development` and the GitHub repo `enterprise-azure-policy-as-code`.

## Process for Development (Maintainers Only)

### Syncing latest Version from GitHub repo to `epac-development` repo

* Create a branch in `epac-development repo` named `feature/sync-from-github`
* Sync GitHub enterprise main branch with `Sync-Repo.ps1`
* Verify changes
* Commit changes to `epac-development` branch `feature/sync-from-github`
* Test and PR `epac-development` branch `feature/sync-from-github` to `epac-development` main branch
* Delete `epac-development` branch `feature/sync-from-github`

### Development in `epac-development` repo

* Each developer owns
  * Management Group in the `epac-development` tenant
  * Folder in the `Test` folder, `pipeline.yml`, and `Set-EnvironmentVariables.ps1` in the `epac-development` repo
  * `Set-EnvironmentVariables.ps1` in your Test folder is used to set the environment variables for your `Test` folders. This is required for interactively using the scripts.
* Create a feature branch in `epac-development` repo named `feature/<your-name>/<github-issue-number>`
* Make and test changes
* PR `epac-development` branch `feature/<your-name>/<github-issue-number>` to `epac-development` main branch
* Validate "prod" build in `epac-development` tenant
* Delete branch `feature/<your-name>/<github-issue-number>`
* Fetch main branch from `epac-development` repo
* Create a branch in GitHub `enterprise-policy-as-code` repo from the issue you working on.
* Fetch that branch in VS Code
* Sync `enterprise-policy-as-code` repo with `Sync-Repo.ps1` from epac-development repo
* Commit changes to `enterprise-policy-as-code` branch created above
* validate the changes for conflicts
* PR `enterprise-policy-as-code` branch created above to the main branch
* Create a [release in GitHub `enterprise-policy-as-code` repo](module-release-process.md)
* Delete the branch in `enterprise-policy-as-code` repo
