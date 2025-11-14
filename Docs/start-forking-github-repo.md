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
