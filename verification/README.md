# Verification

This folder contains proof of implementation — screenshots, test results, and GuardDuty findings captured during deployment.

## What Will Be Here

| File | Contents |
|---|---|
| `screenshots/terraform-plan.png` | Output of `terraform plan` showing resources to be created |
| `screenshots/terraform-apply.png` | Successful `terraform apply` output |
| `screenshots/organizations-console.png` | AWS Organizations console showing OU structure and SCP attachments |
| `screenshots/guardduty-findings.png` | GuardDuty findings dashboard in Security account |
| `screenshots/security-hub-dashboard.png` | Security Hub aggregated findings across accounts |
| `screenshots/cloudtrail-logs.png` | CloudTrail S3 bucket in Logging account with immutable logs |
| `connectivity-tests.md` | Results of on-prem → AWS connectivity tests via Site-to-Site VPN |
| `security-validation.md` | Validation that SCPs block prohibited actions (with deny evidence) |

## Validation Approach

For each security control, I validate it by attempting the action it should block and confirming the deny:

- **deny-root-usage SCP**: Attempt API call with root credentials → confirm `AccessDenied`
- **deny-disable-cloudtrail SCP**: Attempt `cloudtrail:StopLogging` → confirm `AccessDenied`
- **Permission boundary**: Attempt `iam:CreateRole` from bounded role → confirm `AccessDenied`
- **No public subnets**: Confirm no IGW attached to workload VPC, no public route in route tables
- **GuardDuty aggregation**: Simulate finding in workload account → confirm it appears in Security account

Screenshots added as each validation is performed during deployment.
