# 04 — Zero Trust Pillars

> **Status: target design with Terraform examples.** GuardDuty, Security Hub, NAT, and VPN are optional variables; several are disabled by default. A designed control becomes an implementation claim only after it is applied and verified in a sandbox.

## Verify identity explicitly

The Terraform-created role chain is restricted to named operator roles and the AWS Organization ID. Human MFA is enforced by IAM Identity Center or the upstream identity provider. The Terraform trust policies do not check `aws:MultiFactorAuthPresent`, because AWS documents that this key is absent for federated identities.

## Least privilege

The Organizations module attaches SCP guardrails to the Security, Infrastructure, and Workload OUs and directly to the configured member account IDs. The permission boundary is attached to the example workload security-read role. It is not automatically attached to every role in the workload account.

Effective access is constrained by the applicable SCP, the attached permission boundary, and the role's identity policies. Each layer must allow an action, and an explicit deny in any applicable layer overrides an allow.

## Limit network paths

The Terraform creates one private workload VPC and separate Transit Gateway route tables for workload, egress, and optional on-premises connectivity. A default route is created only when the NAT Gateway option is enabled. The module does not define application-specific security-group or NACL rules, so it does not yet demonstrate workload micro-segmentation.

## Assume breach and protect evidence

The Management-account CloudTrail is delivered to a bucket in the Logging account. The bucket policy denies object and bucket deletion, and a member-account SCP adds a separate delete guardrail. These protections do not restrict the Organizations management account, and the bucket is not configured with S3 Object Lock; describe it as deletion-protected rather than immutable.

GuardDuty and Security Hub can be enabled as delegated services, but both options default to disabled to control cost. Enable them only in a sandbox and capture proof that member findings appear in the Security account. Aggregation and delivery behavior have not yet been demonstrated.

## Short-lived access

The two example IAM roles have maximum session durations of one hour. This does not set IAM Identity Center's session lifetime; configure and document that separately in the identity provider.
