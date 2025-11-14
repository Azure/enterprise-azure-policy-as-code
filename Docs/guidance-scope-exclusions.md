# Scope Exclusions

## Overview

There are several means of excluding a scope from a policyAssignment; however, it is not always clear which mechanism is most appropriate for use in a given situation. The purpose of this article is to provide guidance on the subject.

## Decision Making Guidance

There are several ways of accomplishing scope changes, and the logic behind these decisions is fairly straightforward. However, that does not mean that there is an objectively right answer in all cases, and these pieces of guidance should aid in choosing a path forward.

In all cases, simply moving the assignments down to a more specific level could solve the problem, but it is rarely the most efficient. Certainly assigning by each Resource Group can reduce the number of exclusions, but at the cost of a fail-open configuration for new Resource Groups as well as a significantly higher number of assignments. This is rarely, if ever, preferred.

### Decision: Periodic Review

If there is a requirement to review the scope change periodically, to confirm that it is still appropriate, Exemptions are generally the focus. This allows the organization to leverage the built-in functionality within Azure Policy to help manage reviews.

### Decision: Require Manage Scope for a Subset of policySetDefinition

While a decision around the scope will determine to which scope policyAssignments are applied, there are often changes to the Effect in order to descope individual items within a policySet. In this case, NotScope is generally the focus within the policyAssignment in order to provide that level of control.

Example: Exempt a workload contained within a management group from requiring Storage to use TLS 1.2 defined in the policySet [Enforce-EncryptTransit_20241211](https://www.azadvertizer.net/azpolicyinitiativesadvertizer/Enforce-EncryptTransit_20241211.html) in order to support a legacy service which must use TLS 1.1, while retaining the enforcement for all other Services.

### Decision: Scope at policyAssignment or pacSelector

The key guiding factors will be at which scope of *assignments* the exclusion is desired. If it is for all assignments in a pacSelector, items in the Global Settings file will be the focus. However, if the scope is more specific then the policyAssignment configurations or an Exemption should be the focus.

The former is useful when offering autonomy to a hierarchical scope in Azure, the latter when managing the specific needs of a hierarchical scope in Azure when it differs from the [Archetype](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/tailoring-alz) to which it belongs.

## Methods

1. [Exemptions](./policy-exemptions.md)
    1. [Defined in Azure at the level of the object affected by the assignment](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/scope#scope-comparison) using a management file(s) in the `./Definitions/policyExemptions/[pacSelectorName] directory
        1. Option: CSV or JSON file
        1. The introduction of the many new methods of filtration has made JSON reviews more convenient, and is recommended over CSV
    1. *Can* be filtered within a policyAssignment to specific policyDefinitions within a policySetDefinition using `policyDefinitionsReferenceIds`
    1. Includes Azure native mechanism for periodic review requirement using `ExpiresOn`
    1. Can be reported on as exceptions to the definition(s) for which they are defined
1. [NotScopes](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/scope#assignment-scopes)
    1. Defined in Azure at the level of the [policyAssignment](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/scope#assignment-scopes) in which it is configured
    1. *Cannot* be filtered to specific policyDefinitions within a policySetDefinition
1. [GlobalNotScopes](./settings-global-setting-file.md#excluding-scopes-for-all-assignments-with-globalnotscopes)
    1. Defined at the pacEnvironment level in the Global Settings file
    1. Affects *all* policyAssignments in the chosen scope by excluding this scope from them
    1. *Cannot* be filtered to specific policyDefinitions within a policySetDefinition
1. [Desired State Adjustments](./settings-desired-state.md)
    1. Defined at the pacEnvironment level in the Global Settings file
    1. Affects *all* policyAssignments in the chosen scope by excluding these scopes from Desired State Enforcement
    1. This will allow policyAssignments to be deployed within a scope that will not be affected by the configuration [`"desiredState":{"strategy":"full"}`](./settings-desired-state.md)
    1. Scenarios are more extensively outlined in the [Desired State](./settings-desired-state.md)
    1. *Cannot* be filtered within a policyAssignment to specific policyDefinitions within a policySetDefinition

        1. Defined at the pacEnvironment level in the Global Settings file
        1. Removes this scope from EPAC management entirely
    1. Common Scenarios:
        1. [Exclude Resource Groups](./settings-desired-state#exclude-resource-groups)
        1. [Exclude Subscriptions](./settings-desired-state#exclude-resource-groups)
