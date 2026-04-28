# 01 — Account Strategy

## Why Multi-Account

The single biggest architectural  decision in this project is the choice to use separate AWS accounts rather than a single account with IAM-based separation. This is not a complexity preference — it is a security requirement.

IAM policies are powerful but they operate within an account. A sufficiently privileged principal in a single-account setup can modify or delete IAM policies, CloudTrail configurations, GuardDuty detectors, and other security controls. In a multi-account setup, the account boundary is enforced by AWS itself — no IAM policy can cross it.

Three concrete properties that only multi-account provides:

**Blast radius containment.** A compromise of the workload account gives an attacker access to workload resources only. The logging account, security account, and their contents are in separate AWS accounts that the attacker's credentials cannot touch — not because of an IAM policy they could modify, but because they are a different account entirely.

**SCP enforcement.** Service Control Policies are the highest-level permission control in AWS. They can only be applied to accounts within an AWS Organization. A single account cannot benefit from SCPs. Multi-account is a prerequisite for any SCP-based guardrail.

**Audit trail integrity.** An immutable audit trail requires that the account storing logs is separated from the accounts generating logs. If both live in the same account, a compromised admin credential can delete CloudTrail logs. In this architecture, CloudTrail logs land in the Logging account which has an SCP denying all deletes — a workload account credential has no path to that bucket.

## OU Structure

```
Root
├── Management Account          (organizational control only — no workloads)
├── Security OU
│   └── Security Account        (GuardDuty admin, Security Hub aggregator)
├── Infrastructure OU
│   ├── Logging Account         (immutable CloudTrail, VPC Flow Logs)
│   └── Network Account         (Transit Gateway, centralized egress)
└── Workload OU
    └── Workload Account(s)     (application resources)
```

SCPs are attached at the OU level. Any account added to the Workload OU automatically inherits all four guardrails without manual configuration. This is the account vending property that makes the architecture scale.

## Management Account Design

The management account has organizational-level trust — it can apply SCPs, create accounts, and access billing across the organization. Running workloads in the management account would mean a compromised application has organizational-level access.

The management account in this architecture runs no workloads. It exists solely for:
- AWS Organizations management
- SCP creation and attachment
- Billing and cost allocation
- Terraform state management (via S3 backend in this account)

Access to the management account is restricted to the Terraform deployment role and root (MFA enforced, no long-lived credentials).
