# EPAC Development to Production Promotion Process

A guide for maintainers on how to move internal EPAC development (ADO) to production (GitHub).

Assumption: You have completed PR in for EPAC Development in ADO ([https://secinfra.visualstudio.com/\_git/epac-development](https://secinfra.visualstudio.com/_git/epac-development)) and are ready to release to public GitHub EPAC project.

You are using known local path names for EPAC Development repo and GitHub repo, for example:

EPAC Development local repo: `C:\GitRepoClones\epac-development`
EPAC GitHub local repo: `C:\GitRepoClones\enterprise-azure-policy-as-code`

## Code Promotion Process

1. Create a branch in GitHub ([https://github.com/Azure/enterprise-azure-policy-as-code](https://github.com/Azure/enterprise-azure-policy-as-code)).

2. Update local production repo with content from local development repo. In local VS code repo for EPAC GitHub, open terminal:
   `PS C:\GitRepoClones\enterprise-azure-policy-as-code> .\Sync-ToGH.ps1`.

3. Commit changes and sync.

4. Go to [https://github.com/Azure/enterprise-azure-policy-as-code](https://github.com/Azure/enterprise-azure-policy-as-code), go to `Compare and Pull Request`

5. Add PR title and create PR.

6. Complete GitHub Review and merge PR process.

7. Delete branch from GitHub.

8. Go to VSCode for EPAC Release (GitHub) (ex `C:\GitRepoClones\enterprise-azure-policy-as-code`) In Source Control, select main branch. Move to Remotes and fetch, then sync changes.

9. Move to branches, delete local branch (force delete may be required).

10. Open terminal, type `git remote prune origin`

# Module Release Process

This is a guide on how to release a new version of the project - including automated PowerShell module publish. It is used by the EPAC maintainers only.

## GitHub Release Process

1. Navigate to https://github.com/Azure/enterprise-azure-policy-as-code/releases
2. Click on **Draft a new release**
3. Click on **Choose a tag** and enter in the new release version - it should be in the format "v(major).(minor).(build)" i.e. v7.3.4 **Don't forget the v**
4. When prompted click on **Create new tag: vX.X.X on publish**
5. Add a release title - you can just use the new version number.
6. Click on **Generate release notes** to pull all the notes in from related PRs. Update if necessary.
7. Click **Publish Release**

Now just verify the module publish action has run

## Verify Action

1. Click on **Actions**
2. Verify that a workflow run has started with the same name as the release.

It should finish successfully - if there is a failure review the build logs.

# Documentation Release Process

A guide for maintainers on how to update documentation..

1. Modify files in the Docs folder following the format of other files. For a list of acceptable admonitions please see [here](https://squidfunk.github.io/mkdocs-material/reference/admonitions/#supported-types)
2. If you are adding a new file ensure it is added to the `mkdocs.yml` file in the appropriate section. Use the built site to determine where a new document should be placed.
3. Create a PR and merge - the actions will commence automatically. There are two actions which run in the background to update the GitHub Pages site.
