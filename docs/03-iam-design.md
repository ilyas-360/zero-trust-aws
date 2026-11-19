# 03 — IAM Design

> **Status: design and Terraform target.** The Terraform creates one bounded workload security-read role and one Security-account role that can assume it. The boundary does not automatically attach to every workload role. Do not claim account-wide enforcement without an additional tested control.

## Credentials and account access

The Terraform providers use separate named AWS CLI profiles for the Management, Security, Logging, Network, and Workload accounts. Use IAM Identity Center profiles where available; do not store access keys in Terraform variables or the repository. `allowed_account_ids` in each provider makes Terraform fail if a profile resolves to the wrong account.

Human MFA must be required by IAM Identity Center or the upstream identity provider. AWS documents that `aws:MultiFactorAuthPresent` is absent for federated identities, including IAM Identity Center sessions; a `Bool` condition requiring that key in these role trust policies would block this login path. See [AWS global condition context keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-multifactorauthpresent).

## Cross-account role chain

```text
Human operator
  └─ IAM Identity Center session in Management account (MFA enforced by IdP/Identity Center)
      └─ sts:AssumeRole → SecurityAssumeWorkloadReadRole (Security account, max 1 hour)
          └─ sts:AssumeRole → WorkloadSecurityReadRole (Workload account, max 1 hour)
              └─ Read-only security evidence; workload permission boundary attached
```

The Security role trusts the exact `management_operator_role_arn` supplied in local `terraform.tfvars`. The workload role trusts only the Security-account role created by this Terraform module. Both trust policies also require the principal to belong to this AWS Organization. The Security role's identity policy grants `sts:AssumeRole` only on the workload security-read role ARN.

## Permission boundary

`policies/iam/permission-boundaries.json` is an annotated example. Terraform removes underscore-prefixed explanatory fields before passing the policy to IAM. The resulting boundary:

- Allows only the read operations required by the example role.
- Explicitly denies the listed IAM privilege-escalation actions.
- Denies changes to Organizations and the listed centralized security services.

Terraform attaches this boundary to `WorkloadSecurityReadRole`. Creating the managed policy alone would not constrain any role. The repository does not yet prevent an administrator from creating other workload roles without a boundary; that stronger account-wide property needs a separate tested SCP/control.

## Session lifetime and validation

Both example roles have `max_session_duration = 3600`. Validate in a sandbox by checking the role trust and attached boundary in IAM, then use the Security role to assume the workload read role and confirm the read-only actions succeed while an explicitly denied IAM write action returns `AccessDenied`.

Record the test principal, exact action, expected and observed result, timestamp, and sanitized screenshot in [`verification/README.md`](../verification/README.md). Do not test with root credentials or production roles.
