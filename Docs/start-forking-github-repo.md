# Forking the GitHub Repo - an Alternate Installation Method

Instead of installing `EnterprisePolicyAsCode` from the PowerShell Gallery, you can clone the GitHub repository and use the scripts described below to install the script source code. This is useful, if your organization has overly restrictive policies on installing PowerShell modules from the PowerShell Gallery. It can also be useful if you want to contribute EPAC source code to the project.

## Changes to the Forking Process

With the ability to provide prerelease versions via release and PowerShell - if you are working in a forked repo you should also clone the tags from the original source to allow your forked repo to pin to specific releases.

1. Add an upstream remote containing the original release `git remote add upstream https://github.com/Azure/enterprise-azure-policy-as-code.git`
1. Fetch the tags from the upstream - `git fetch --tags upstream`
1. Push tags to the fork - `git push --tags`

Tags are not automatically synced to a forked repo so you must perform this task each time you sync your fork with the main project.

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
          1. Review the [`Sync-Repo`](#sync-repops1) documentation for additional information on the folders which are destroyed and recreated as part of the version upgrade process for additional insight on this topic.

![image](Images/Sync-Repo.png)

## Syncing latest Version from GitHub repo

1. Fetch changes from GitHub to `MyForkRepo`.
2. Execute [`Sync-Repo`](#sync-repops1) to copy files from `MyForkRepo` to `MyWorkingRepo` feature branch.
3. PR `MyWorkingRepo` feature branch.

## Contribute to GitHub

1. Execute [`Sync-Repo`](#sync-repops1) to copy files from `MyWorkingRepo` to `MyForkRepo` feature branch.
    1. **Be sure not to copy internal references within your files during your sync to MyForkRepo.**
2. PR `MyForkRepo` feature branch.
3. PR changes in your fork (`MyForkRepo`) to GitHub.
4. GitHub maintainers will review the PR.

## Sync-Repo.ps1

The repo contains script to synchronize directories in both directions: `Sync-Repo.ps1`. It only works if you do not modify:

* `Docs`, `Scripts`, `Module` and `StarterKit` directories
* `*.md`, `*.ps1`, `*.yml`, and `LICENSE` files in repo root directory

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `SourceDirectory` | Required | Directory with the source (forked repo) |
| `DestinationDirectory` | Required | Directory with the destination (your private repo) |
| `SuppressDeleteFiles` | Optional | Switch parameter to suppress deleting files in `$destinationDirectory` tree |

## Process for Development (Maintainers Only)

> [!WARNING]
> This is Intended for maintainers only: It documents how to move internal EPAC development (ADO) to production (GitHub).

Assumptions:

* You have completed PR in for EPAC Development in ADO and are ready to release to public GitHub EPAC project.
* You are using known local path names for EPAC Development repo and GitHub repo, for example:
  * EPAC Development local repo: `C:\GitRepoClones\epac-development`
  * EPAC GitHub local repo: `C:\GitRepoClones\enterprise-azure-policy-as-code`

### Sync-FromGH.ps1 and Sync-ToGH.ps1

Sync-FromGH.ps1 and Sync-ToGH.ps1 are a wrapper around Sync-Repo.ps1 used by the EPAC maintainers to simplify syncing their development repo `epac-development` and the GitHub repo `enterprise-azure-policy-as-code`.

### Syncing latest Version from GitHub repo to `epac-development` repo

* Create a branch in `epac-development repo` named `feature/sync-from-github`
* Sync GitHub enterprise main branch with `Sync-FromGH.ps1`
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
* Create a release in [GitHub `enterprise-policy-as-code` repo](#)
* Delete the branch in `enterprise-policy-as-code` repo

### Code Promotion Process

> [!TIP]
> Modify mkdocs.yml after adding markdown files to the Docs folder.

This process is used to promote code from the EPAC Development repo to the EPAC GitHub repo.

1. Create a branch in GitHub ([https://github.com/Azure/enterprise-azure-policy-as-code](https://github.com/Azure/enterprise-azure-policy-as-code)).
2. Update local production repo with content from local development repo. In local VS code repo for EPAC GitHub, open terminal:
   `PS C:\GitRepoClones\enterprise-azure-policy-as-code> .\Sync-ToGH.ps1`.
3. Commit changes and sync.
4. Go to [https://github.com/Azure/enterprise-azure-policy-as-code](https://github.com/Azure/enterprise-azure-policy-as-code), go to `Compare and Pull Request`
5. Add PR title and create PR.
6. Complete GitHub Review and merge PR process.
7. Delete branch from GitHub.
8. Go to VSCode for EPAC Release (GitHub) (`C:\GitRepoClones\enterprise-azure-policy-as-code`)
9. In Source Control, select main branch. Move to Remotes and fetch, then sync changes.
10. Move to branches, delete local branch (force delete may be required).
11. Open terminal, type `git remote prune origin`
12. Verify that the documents [have been published](https://aka.ms/epac).

### GitHub Releases

This is a guide on how to release a new version of the project - including automated PowerShell module publish. It is used by the EPAC maintainers only.

1. Navigate to <https://github.com/Azure/enterprise-azure-policy-as-code/releases>
2. Click on **Draft a new release**
3. Click on **Choose a tag** and enter in the new release version - it should be in the format "v(major).(minor).(build)" i.e. v7.3.4 **Don't forget the v**
4. When prompted click on **Create new tag: vX.X.X on publish**
5. Add a release title - you can just use the new version number.
6. Click on **Generate release notes** to pull all the notes in from related PRs. Update if necessary.
7. Click **Publish Release**
8. Click on **Actions**
9. Verify that a workflow run has started with the same name as the release.
10. Verify that the module has been published to the [PowerShell Gallery](https://www.powershellgallery.com/packages/EnterprisePolicyAsCode).
