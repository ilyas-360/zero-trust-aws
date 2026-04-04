# 04 — Zero Trust Pillars

Zero Trust is not a product you buy or a checklist you complete. It is a security model built on one principle: **never assume trust, always verify it explicitly.** Here is how each pillar maps to a concrete implementation in this architecture.

## Never Trust, Always Verify

Every cross-account action requires explicit verification. There are no trust relationships that say "trust everything from account X." Every trust policy has conditions:

- `aws:PrincipalOrgID` — only principals from within this Organization
- `aws:MultiFactorAuthPresent` — MFA must have occurred
- `aws:MultiFactorAuthAge` — MFA must have occurred recently (< 1 hour)
- Source IP conditions on sensitive roles — VPN required for privileged access

A valid AWS credential is not sufficient to assume a role. The credential must also satisfy all conditions. This is the "always verify" property — identity alone is not trust.

## Least Privilege Everywhere

Two independent enforcement layers:

**SCPs** set the maximum permissions at the organizational level. No account in the Workload OU can exceed what the SCPs permit, regardless of what IAM policies exist in that account.

**Permission boundaries** set the maximum permissions at the role level within an account. No role can exceed what its boundary permits, regardless of what managed policies are attached.

The result: effective permissions = intersection of (SCP) ∩ (permission boundary) ∩ (identity policy). All three must allow an action for it to succeed.

## Assume Breach

The architecture is designed assuming any workload account can be fully compromised at any time. The question is not "how do we prevent compromise" but "what can an attacker do if they have full control of a workload account?"

Answer in this architecture:
- Access workload resources in that account only
- Cannot reach other accounts (TGW route table isolation)
- Cannot disable monitoring (SCP-protected)
- Cannot delete logs (SCP + S3 bucket policy in separate account)
- Cannot suppress GuardDuty findings (findings are in the Security account)
- Cannot persist beyond 1 hour (short session durations)

The Security team sees everything in real time regardless of what the attacker does in the workload account.

## Just-In-Time Access

No standing access exists. Access is obtained when needed, scoped to what is needed, and expires automatically:

- Maximum role session duration: 1 hour
- No IAM users with persistent access keys
- No long-term credentials stored anywhere
- Re-authentication required for each work session

## Continuous Verification

GuardDuty monitors all accounts continuously for threat indicators using AWS threat intelligence, ML anomaly detection, and behavioral analysis. CloudTrail records every API call. Security Hub aggregates findings from both.

Critically: these controls run in accounts that workload operators cannot modify. Continuous verification cannot be disabled by a compromised workload account.
