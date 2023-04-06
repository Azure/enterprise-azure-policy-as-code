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

* `Docs`, `Scripts` and `StarterKit` directories
* `CODE_OF_CONDUCT.md`, `LICENSE`, `README.md` (this file), `SECURITY.md`, `SUPPORT.md` and `Sync-Repo.ps1` in root folder

|Parameter | Required | Explanation |
|----------|----------|-------------|
| `sourceDirectory` | Required | Directory with the source (forked repo) |
| `destinationDirectory` | Required | Directory with the destination (your private repo) |
| `suppressDeleteFiles` | Optional | Switch parameter to suppress deleting files in `$destinationDirectory` tree |
