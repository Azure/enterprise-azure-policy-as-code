# Advanced Configuration Scenarios

The following sections cover various Advanced Configuration scenarios.

## Cloud Environment with Unsupported/Missing Policy Definitions

In some multi-tenant implementations, not all policies, policy sets, and/or assignments will function in all tenants, usually due to either built-in policies that don't exist in some tenant types or unavailable resource providers.  In order to facilitate multi-tenant deployments in these scenarios, utilize the `epacCloudEnvironments` property to specify which cloud type a specific file should be considered in.

The allowed values are: "AzureCloud", "AzureChinaCloud" or "AzureUSGovernment".

### Example 1: Policy / PolicySet

To have a Policy or PolicySet definition deployed only to epacEnvironments that are China cloud tenants, add an "epacCloudEnvironments" property to the metadata section of the file like this:

```json
{
  "displayName": "",
  "description": "",
  "metadata": {
    "epacCloudEnvironments": [
      "AzureChinaCloud"
    ]
  }
}
```

### Example 2: Policy Assignment

To have a Policy Assignment deployed only to epacEnvironments that are China cloud tenants, add an "epacCloudEnvironments" property within the top section of the assignment file like this:

```json
{
  "nodename": "/root",
  "epacCloudEnvironments": [
      "AzureChinaCloud"
    ],
  "definitionEntry": {
        "policySetId": ""
    },
  "children": [
  ]
}
```