# 06 — Security Observability

> **Status: CloudTrail and Flow Logs are in Terraform; GuardDuty and Security Hub are optional.** No AWS deployment or finding aggregation has been captured yet. Do not claim live detection until it is enabled and verified.

## Data paths

| Source | Collection | Destination | Current code status |
|---|---|---|---|
| AWS API management events | Multi-Region organization CloudTrail created from the Management account | Versioned, encrypted S3 bucket in the Logging account | Implemented in Terraform; delivery not verified |
| Network traffic in Network VPC | VPC Flow Logs | CloudWatch Logs in Network account | Implemented in Terraform; delivery not verified |
| Network traffic in Workload VPC | VPC Flow Logs | CloudWatch Logs in Workload account | Implemented in Terraform; delivery not verified |
| Threat findings | GuardDuty delegated admin in Security account | Security account detector and optional EventBridge/SNS alert | Optional and disabled by default |
| Security posture | Security Hub admin in Security account; FSBP and CIS 1.4.0 subscriptions | Security account | Optional and disabled by default |
| Configuration drift | AWS Config | — | Not implemented in this Terraform project |

## Organization CloudTrail

The `logging` module creates the destination bucket in the Logging account and the organization trail in the Management account. The bucket policy includes CloudTrail's bucket ACL check and a write permission scoped to `AWSLogs/<organization-id>/*`, the management account, and this trail. S3 public access is blocked, default encryption and versioning are enabled, and deletion is denied by the bucket policy. A separate SCP denies deletion of matching log buckets and objects in member accounts.

These controls provide deletion protection for member-account principals, but the Management account is not restricted by SCPs, and the bucket does not use S3 Object Lock. Describe the storage as **deletion-protected**, not immutable. Log-file validation detects changes to delivered CloudTrail log files; it does not prevent an authorized administrator from changing configuration.

CloudTrail S3 data events are disabled unless explicit object ARNs are listed in `s3_data_event_arns`. This avoids enabling high-volume data-event logging for every bucket by default.

## GuardDuty and Security Hub

Set `enable_guardduty = true` to register the Security account as delegated administrator, enable its detector, and configure organization auto-enablement. Set `enable_securityhub = true` to register Security Hub administration, enable it in the Security account, configure member auto-enablement, create an aggregator configured to link all Regions, and subscribe in the configured Region to AWS Foundational Security Best Practices and CIS AWS Foundations Benchmark 1.4.0. The Terraform does not enable GuardDuty or Security Hub in every allowed Region, so do not infer full multi-Region detection from the aggregator setting. Security Hub `auto_enable` applies to new organization accounts; existing accounts need enrollment/enablement handled separately. Security Hub control findings also require AWS Config recording, which this repository does not configure.

If GuardDuty is enabled, an EventBridge rule sends severity 7+ findings to SNS. Set `alert_email_address` to create an email subscription; the recipient must confirm the SNS subscription. Without a confirmed subscription, the topic has no email recipient. These services are billable, so review pricing and sandbox scope before enabling them.

## Validation evidence

After deployment, check **CloudTrail → Trails** in the Management account, then verify a new object appears in the Logging account bucket. Check **VPC → Your VPCs → select VPC → Flow logs** and **CloudWatch → Log groups** in each source account. If enabled, capture **GuardDuty → Accounts/Findings** and **Security Hub → Findings** in the Security account, including a test member-account finding.

Add timestamps and observed results to `verification/security-validation.md`. Finding delivery latency and event routing must be measured in the sandbox; do not describe them as real-time without evidence.
