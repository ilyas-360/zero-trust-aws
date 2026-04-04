# 03 — IAM Design# 03 — IAM Design

## No Long-Lived Credentials

No IAM users with access keys exist in this architecture. This is a hard requirement, not a preference. Long-lived access keys are the single most common source of AWS credential compromise — they can be leaked in code repositories, CI/CD logs, or environment variables and remain valid until manually rotated.

All access uses role assumption chains that produce temporary credentials with a maximum 1-hour TTL. A leaked session token is worthless after expiry.

## Permission Boundaries

A permission boundary is a managed IAM policy that sets the maximum permissions any role can have, regardless of what inline policies or managed policies are attached to it.

Without permission boundaries, a role with `iam:CreateRole` and `iam:AttachRolePolicy` can create a new role with `AdministratorAccess` — a complete privilege escalation within the account. With a permission boundary that excludes IAM write actions, this path is closed. The escalation attempt produces an `AccessDenied` error even if the role's inline policy allows those IAM actions.

The permission boundary in this project:
- Allows specific service actions needed for workload operation (EC2, S3, RDS, Lambda, etc.)
- Explicitly denies all IAM write actions
- Explicitly denies all Organizations API calls
- Explicitly denies disabling GuardDuty, CloudTrail, Security Hub, or Config

## Role Assumption Chain

```
Developer (MFA authenticated)
    │
    ▼ sts:AssumeRole + MFA condition
Management Account Role
    │
    ▼ sts:AssumeRole + PrincipalOrgID condition + MFA age < 1hr
Workload Account Role (scoped to specific service)
    │   ← Permission boundary enforced here
    ▼
Resource Access (1-hour session, then expired)
```

The `aws:PrincipalOrgID` condition on every cross-account trust policy ensures only principals from within this AWS Organization can assume the role. An external attacker who discovers a role ARN cannot assume it — the condition fails immediately.

## Cross-Account Trust Conditions

Every trust policy in this architecture includes these conditions:

```json
"Condition": {
  "StringEquals": {
    "aws:PrincipalOrgID": "o-XXXXXXXXXX"
  },
  "Bool": {
    "aws:MultiFactorAuthPresent": "true"
  },
  "NumericLessThan": {
    "aws:MultiFactorAuthAge": "3600"
  }
}
```

MFA must be present AND the MFA authentication must have occurred within the last hour. A valid session token from a user who authenticated 3 hours ago cannot assume cross-account roles — re-authentication is required.
MFA must be present AND the MFA authentication must have occurred within the last hour. A valid session token from a user who authenticated 3 hours ago cannot assume cross-account roles — re-authentication is required.
