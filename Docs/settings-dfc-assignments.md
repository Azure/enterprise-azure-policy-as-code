# Managing Defender for Cloud Assignments

Defender for Cloud (DFC) is a suite of Azure Security Center (ASC) capabilities that helps you prevent, detect, and respond to threats. It provides you with integration of Microsoft's threat protection technology and expertise. For more information, see [Azure Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/).

## Defender for Cloud Assignments for Defender Plans

> [!NOTE]
> DfC manages the Policy Assignments for Defender Plans when a plan is enabled. EPAC v9.0.0 and later **never** manage these Policy Assignments.

![image.png](Images/dfc-defender-plans-settings.png)

## Defender for Cloud Security Policy Assignments

DfC automatically assigns `Microsoft cloud security benchmark` to each new subscription enrolled in Defender for Cloud. It also adds compliance Assignments when a Compliance framework is enabled, such as NIST 800-53 Rev 5, NIST 800-171, etc.

These Assignments are enabled/created at the subscription level or at management group level. Since these Policies are set to to `Audit` and you will want to set many of them to `Deny`, it is recommended that EPAC manages them at the management group level. This is the default behavior.

> [!WARNING]
> EPAC behavior for Security Policy **is controlled by** the `keepDfcSecurityAssignments` in `desiredState`.

- If set to `true` or `strategy` is `ownedOnly`, EPAC will **not** remove "DfC Security Policy Assignments" created by Defender for Cloud.
- If **omitted** or **set to `false`** and `strategy` is `full`, EPAC will remove "DfC Security Policy Assignments" created by Defender for Cloud.

```json
"desiredState": {
    "keepDfcSecurityAssignments": true
}
```

![image.png](Images/dfc-security-policy-sets-settings.png)
