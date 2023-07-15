# GitHub repository: How to clone or fork, update and contribute

Git lacks a capability to ignore files/directories during a PR only. This repo has been organized so that Definitions and Pipeline folders are not touched by syncing latest update from GitHub to your repo or reverse syncing to contribute to the project.

!!! note
    This steps are no longer necessary if you use the [PowerShell Module](powershell-module.md). You may still need to copy files from the starter kit.
    You can still use this method to continue your current approach or to [contribute improvements](#contribute-to-github).

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

## Sync-Repo.ps1

The repo contains a script to synchronize directories in both directions: `Sync-Repo.ps1`. It only works if you do not modify:

* `Docs`, `Scripts`, `Module` and `StarterKit` directories
* `*.md`, `*.ps1`, `*.yml`, and `LICENSE` files in repo root directory

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `SourceDirectory` | Required | Directory with the source (forked repo) |
| `DestinationDirectory` | Required | Directory with the destination (your private repo) |
| `SuppressDeleteFiles` | Optional | Switch parameter to suppress deleting files in `$destinationDirectory` tree |

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
