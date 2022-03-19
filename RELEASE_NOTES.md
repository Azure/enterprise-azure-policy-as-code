# Enterprise Policy as Code 2.1 Release Notes

Latest update: March 18th, 2022

## Introduction

These release notes describe issues specific to the Enterprise Policy as Code release.

## Known issues

- None

## Licenses

Enterprise Policy as Code is licensed under the MIT License.

## Changes in this Release

Added `ReleaseNotes.md`

### New Features

- Separation of folders to simplify merging changes into forks an copies.
- Script `Scripts\Operations\New-AzPolicyReaderRole.ps1` to create the required role `Policy Reader`.
- Initiative feature to merge multiple built-in initiatives into a single custom initiative
- Script simplifications.
- Improved pipelines, skipping unnecessary stages, jobs, and steps.
- Separation of environment specific values, such as tenant id and Azure scopes into a single directory `Definitions`. Moved configuration values from `Scripts\Config` PowerShell scripts to `Definitions/global-settings.jsonc`
- Documentation improvements and reorg.
  - Service connections, roles and stages
  - Better diagrams
  - Clarifications
  - Reorged structure from centralized files in`Docs` to `README.md` in the folders where the information applies.
