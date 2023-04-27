# Module Release Process

This is a guide on how to release a new version of the project - including automated PowerShell module publish.

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

