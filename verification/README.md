# Terraform setup, review, and evidence procedure

**Current state:** No AWS deployment screenshots or completed control tests are stored here. The steps below describe how to configure and review the project in a dedicated sandbox. An AWS apply is intentionally left to you after you review the plan and confirm the accounts.

## 1. Prepare a dedicated sandbox

This Terraform root expects five **existing** AWS accounts in one Organizations organization: Management, Security, Logging, Network, and one Workload account. It creates OU containers but does not create accounts or move them. Do not use a production organization or accounts with real workloads. Confirm you have permission to manage Organizations and each member-account service used by the configuration.

The Management operator role must already exist and must be trusted by the Security role Terraform creates. Its permissions must allow `sts:AssumeRole` on `SecurityAssumeWorkloadReadRole`. Configure human MFA in IAM Identity Center or the upstream identity provider. Terraform does not configure Identity Center, user MFA, root MFA, account recovery, or the operator's permission set.

## 2. Configure one AWS CLI profile per account (Windows PowerShell)

Install/update AWS CLI v2 and Terraform 1.5 or newer. For each account, run the AWS SSO wizard and choose the account and permission set intended for that account:

```powershell
aws configure sso --profile management
aws configure sso --profile security
aws configure sso --profile logging
aws configure sso --profile network
aws configure sso --profile workload
```

The wizard asks for your IAM Identity Center start URL, Identity Center Region, account, role/permission set, and default CLI Region. Use the same profile names in `terraform.tfvars`, or change those values there. Sign in, then verify each caller independently:

```powershell
aws sso login --profile management
aws sso login --profile security
aws sso login --profile logging
aws sso login --profile network
aws sso login --profile workload

aws sts get-caller-identity --profile management
aws sts get-caller-identity --profile security
aws sts get-caller-identity --profile logging
aws sts get-caller-identity --profile network
aws sts get-caller-identity --profile workload
```

Record the 12-digit `Account` values privately. Confirm they match the intended five account IDs before Terraform. Do not paste session tokens, access keys, or credentials into the repository or chat.

## 3. Fill local Terraform inputs

From the repository root, create the ignored local input file:

```powershell
Copy-Item .\terraform\terraform.tfvars.example .\terraform\terraform.tfvars
```

Open `terraform\terraform.tfvars` in VS Code or Notepad. Replace every example account ID with the corresponding ID from the five `get-caller-identity` results. Keep the five profile names aligned with your SSO profiles. Set `management_operator_role_arn` to the exact IAM role ARN for the Management-account permission set (AWS Console → IAM → Roles; search for the `AWSReservedSSO_...` role and copy its **ARN**). Set `cloudtrail_bucket_name` to a globally unique name beginning `zero-trust-cloudtrail-logs-`, such as a prefix plus a random suffix. Keep NAT, GuardDuty, Security Hub, VPN, and data events disabled until their costs and prerequisites are understood.

The allowed-region SCP is injected from `allowed_regions`; keep `aws_region` in that list. Choose non-overlapping VPC CIDRs that do not overlap your on-premises network or any connected network. The default VPN input is `null`.

Check that the local file is ignored before proceeding:

```powershell
Set-Location .\terraform
 git status --short
 git check-ignore terraform.tfvars
```

`git check-ignore` should print `terraform.tfvars`. If it does not, stop and fix `.gitignore` before creating a commit.

## 4. Existing Organizations: inspect and import before planning

The organization module declares an Organization with SCP support and three OUs. If you already have an Organization, do not allow Terraform to create another one. Inspect current policy types, OUs, policies, and attachments first. From the `terraform` directory, import the Organization:

```powershell
terraform import -var-file=terraform.tfvars module.organizations.aws_organizations_organization.root o-xxxxxxxxxx
```

If an OU named `Security`, `Infrastructure`, or `Workload` already exists, import that OU into its corresponding Terraform address rather than creating a duplicate:

```powershell
terraform import -var-file=terraform.tfvars module.organizations.aws_organizations_organizational_unit.security ou-xxxxxxxxxx
terraform import -var-file=terraform.tfvars module.organizations.aws_organizations_organizational_unit.infrastructure ou-yyyyyyyyyy
terraform import -var-file=terraform.tfvars module.organizations.aws_organizations_organizational_unit.workload ou-zzzzzzzzzz
```

If equivalent named SCPs or policy attachments already exist, reconcile/import those resources too before applying; use AWS Organizations → Policies → Service control policies and each target's policy list to identify IDs. Never attach duplicate policies blindly. For an attachment, Terraform's import ID format is `<policy-id>/<target-id>`; confirm the matching provider version's import documentation before using it.

If Resource Access Manager sharing with the Organization is already enabled, import that existing setting rather than trying to create it again:

```powershell
terraform import -var-file=terraform.tfvars module.networking.aws_ram_sharing_with_organization.main <management-account-id>
```

Review the imported state and full plan for any attempt to change existing organization structure or account permissions. A policy attachment can immediately deny API operations across an account. Do not apply until the plan has been reviewed and the accounts are confirmed disposable sandbox accounts.

## 5. Format, initialize, validate, and plan

These commands run locally and do not deploy resources:

```powershell
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

For a plan, first ensure all five SSO sessions are current. Then:

```powershell
terraform plan -var-file=terraform.tfvars
```

Read the entire plan. Confirm that each create/update targets the intended account and Region. Check expected costs and cleanup for Transit Gateway, optional NAT, VPN, CloudTrail, CloudWatch Logs, GuardDuty, and Security Hub. The defaults disable optional billable services; enabling one still requires cost review. Do not apply based solely on a successful `validate` or plan.

Terraform state is local because no remote backend is configured. State can contain sensitive values. Keep it private, back it up securely, and never commit it. `.gitignore` covers state, plan files, local variable files, and `.terraform/`.

## 6. Deploy only after you approve the sandbox plan

This repository supplies deployment code and a plan procedure, but **you** must review and decide whether to apply it in AWS. If you choose to apply, run it only after confirming all five caller identities, Organization imports, the full reviewed plan, permissions, and estimated cost. Keep a copy of the plan and state private. Record resource IDs and cleanup steps. Do not use the Management account for application workloads.

## 7. Capture authentic evidence screenshots

Only capture screenshots after observing the live sandbox. Do not fabricate console screens or present a diagram as runtime proof. On Windows, use `Win + Shift + S`, select **Window Snip** or **Rectangular Snip**, capture the relevant console/terminal area, and save a sanitized PNG into `verification/screenshots/`. Create that directory if needed. Hide account IDs, email addresses, public IPs, resource names that reveal private details, and browser tabs unrelated to the evidence. Keep unredacted originals private. Add the test date, expected result, observed result, and filename to `verification/security-validation.md`.

| File | Exact console path / action | Evidence to include |
|---|---|---|
| `01-organizations-ous.png` | AWS Console → **AWS Organizations** → **AWS accounts** / **Organizational units** | The three OU containers and their account membership. This code does not move accounts; show the actual state and do not imply placement happened automatically. |
| `02-scp-attachments.png` | Organizations → **Policies** → **Service control policies** → open each lab policy → **Targets** | Policy names and exact targets. Include only policies that exist in the live org. |
| `03-scp-deny-test.png` | A sandbox member-account terminal running one harmless, explicitly denied test, plus the matching CloudTrail event if available | `AccessDenied`, command, role (redacted), timestamp, and SCP attachment. Never test with root. |
| `04-iam-boundary.png` | AWS Console → **IAM** → **Roles** → `WorkloadSecurityReadRole` → **Permissions** | The role's attached `WorkloadPermissionBoundary` and its read-only permission policy. |
| `05-private-vpc-routes.png` | VPC Console → **Your VPCs**, then **Subnets** and **Route tables** for the Workload VPC | Private subnet CIDRs, disabled public-IP assignment, and routes. If NAT is disabled, there should be no default route to TGW; if enabled, show the TGW path. |
| `06-transit-gateway.png` | VPC Console → **Transit gateways** → select TGW → **Attachments** and **Transit gateway route tables** | Available attachment state, route-table associations, and routes. Capture only after cross-account acceptance completes. |
| `07-cloudtrail-trail.png` | AWS Console → **CloudTrail** → **Trails** → `zero-trust-organization-trail` | Multi-Region and organization-trail settings, Management account context, and logging bucket destination. |
| `08-audit-log-object.png` | S3 Console in Logging account → **Buckets** → configured bucket → **Objects** | A real delivered object under `AWSLogs/<organization-id>/<account-id>/CloudTrail/<region>/`, plus bucket Properties showing versioning, encryption, and Block Public Access. Redact IDs/object keys. |
| `09-guardduty-admin.png` | GuardDuty Console in Security account → **Accounts** / **Settings** | Delegated administrator and member status, only if GuardDuty was enabled and enrollment completed. |
| `10-security-hub-findings.png` | Security Hub Console in Security account → **Findings** | A finding from a lab account and the selected standards, only if enabled; redact account identifiers. |
| `11-connectivity-test.png` | VPC → **Site-to-Site VPN connections** plus the customer gateway terminal/test host | Tunnel status and a controlled on-prem-to-workload test. A VPN resource alone is not proof of end-to-end connectivity. |
| `12-flow-logs.png` | VPC → **Your VPCs** → select VPC → **Flow logs**; CloudWatch → **Log groups** | Flow Log state and a real record in the source account's configured log group. These logs are not centralized in the Logging account. |
| `13-alert-delivery.png` | EventBridge → **Rules** and SNS → **Subscriptions** in Security account; then show a received test/real alert with private data hidden | Event rule target, confirmed email subscription, and actual delivery. A pending subscription is not working alert delivery. |
| `14-cleanup.png` | Terraform terminal after reviewed destroy, then relevant AWS resource pages | Successful cleanup and confirmation that billable lab resources are gone. Do not destroy the Organization or accounts as part of routine teardown. |

A screenshot supports only what is visible. For example, a bucket settings screenshot is not evidence that CloudTrail delivered an object; a rule configuration screenshot is not evidence that an alert reached an inbox.

## 8. Record control tests

Create `verification/security-validation.md` with one record per test:

```text
Date/time and timezone:
Sandbox account/role (redacted):
Control and Terraform resource/policy:
Command or exact console action:
Expected result:
Observed result:
Evidence screenshot/log filename:
Cleanup completed:
```

Safe checks include inspecting routes, confirming a trail delivered logs, testing the example role's read-only access, and using a disposable sandbox role to verify one deny. Do not test root restrictions by signing in as root. Do not run destructive tests, penetration simulations, or tests against production resources.

## Completion labels

- **Designed:** architecture/policy intent is documented.
- **Implemented:** Terraform was applied to the sandbox and the resource exists.
- **Validated:** a documented test observed the expected behavior and evidence is recorded.

A JSON policy, Terraform validation, a plan, or a screenshot of configuration alone does not prove a control was validated.
