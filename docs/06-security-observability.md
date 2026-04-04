# 06 — Security Observability

## Detection Pipeline

```
Event Source              Collection                Aggregation           Action
─────────────────────     ─────────────────────     ─────────────────     ──────────────
API calls (all accounts)  CloudTrail (org trail)    S3 logging account    Athena queries
Network traffic           VPC Flow Logs             CloudWatch Logs       Metric alarms
Threat intelligence       GuardDuty (all accounts)  Security Hub          EventBridge → SNS
Config changes            AWS Config                Security Hub          Compliance score
```

## Why GuardDuty Delegated Admin Lives in the Security Account

GuardDuty findings from all member accounts aggregate to the Security account automatically. An attacker who fully compromises a workload account sees their own GuardDuty findings generated — but cannot suppress or delete them. The findings are owned by the Security account detector, not the workload account.

This is the most important design decision in the observability layer. **Detection that can be disabled by an attacker is not detection.**

## CloudTrail: Immutable Organization Trail

A single organization trail captures API calls from all accounts across all regions. Log files land in the Logging account S3 bucket which has:

1. A deny-delete S3 bucket policy (resource-level protection)
2. A deny-disable-cloudtrail SCP (organizational-level protection)
3. Log file validation enabled (SHA-256 hash of each log file — tampering is detectable)

An attacker would need to compromise the Logging account AND successfully modify an SCP from the Management account to destroy the audit trail. Both independently protect against log deletion.

## Sample Detection Scenario

**Scenario: EC2 instance credentials used from external IP**

1. Attacker exploits web app vulnerability, retrieves EC2 instance role credentials via metadata endpoint
2. Attacker uses credentials from their IP (outside VPC CIDR)
3. GuardDuty generates `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS` or `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`
4. Finding aggregates to Security account Security Hub within minutes
5. EventBridge rule matches HIGH severity finding → SNS alert to security team
6. CloudTrail records exact API calls made with the stolen credential, source IP, resource ARNs
7. VPC Flow Logs show network path of original exfiltration attempt

**What the attacker cannot do:**
- Delete CloudTrail records of their actions (SCP-protected, separate account)
- Suppress the GuardDuty finding (Security account ownership)
- Use credentials beyond 1-hour session expiry
- Reach other accounts with the stolen EC2 role credentials (PrincipalOrgID + MFA conditions block cross-account assumption)

## Security Hub Standards

Two compliance frameworks are continuously evaluated:

**AWS Foundational Security Best Practices** — AWS-managed checks covering IAM, S3, EC2, RDS, and other services. Findings appear within minutes of a configuration change.

**CIS AWS Foundations Benchmark** — Industry-standard baseline controls. Provides a compliance score visible in the Security Hub dashboard.

Failed checks generate findings that aggregate alongside GuardDuty detections — giving a unified view of both active threats and configuration drift.
