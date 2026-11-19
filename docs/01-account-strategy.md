# 01 — Account Strategy

> **Implementation status:** The Terraform root expects five existing, dedicated AWS accounts. It does not create accounts or move them into OUs. No AWS deployment is evidenced in this repository.

## Account roles

| Account | Provider alias | Resources managed here |
|---|---|---|
| Management | `aws.management` | Organizations, SCPs, OU containers, delegated-admin registration, organization CloudTrail, RAM organization sharing |
| Security | `aws.security` | Cross-account audit role, GuardDuty detector/configuration, Security Hub, alert topic |
| Logging | `aws.logging` | CloudTrail S3 bucket, versioning, encryption, public access block, bucket policy |
| Network | `aws.network` | Transit Gateway, RAM share, egress VPC/NAT, VPN endpoint, Network-account Flow Logs |
| Workload | `aws.workload` | Example audit role and boundary, private VPC/subnets, TGW attachment, workload Flow Logs |

Each alias uses a separate local AWS CLI profile and an `allowed_account_ids` check. Configure and authenticate every profile before running Terraform. The profile's SSO permission set must have the permissions needed by the resources assigned to that account. The Management operator role also needs `sts:AssumeRole` permission for `SecurityAssumeWorkloadReadRole`; Terraform does not edit the operator's permission set.

## Organization behavior and prerequisites

The Organizations module manages an Organization resource, three OU containers, five SCPs, and attachments. It attaches policies to the OUs and directly to the four configured member accounts so those accounts are guarded even before they are moved into the intended OUs. The module does **not** create the member accounts or move them. Existing organization and OU resources must be imported or reconciled before deployment; never point this configuration at an organization containing production accounts.

The SCPs do not restrict the Organizations management account. The new `deny-delete-cloudtrail-logs` SCP protects matching log bucket names in member accounts, while the Logging bucket policy denies object/bucket deletion in the Logging account. Neither is S3 Object Lock, and neither prevents a sufficiently privileged management-account operator from changing organization configuration. Describe the storage as deletion-protected, not immutable.

Before using an existing Organization:

1. Confirm the Organization is in `ALL` feature mode and that its current policy types and OUs are understood.
2. Back up and review the existing Terraform state and AWS organization configuration.
3. Import the Organization and any existing named OUs that Terraform will manage; do not create duplicates.
4. Inspect the complete plan. Enabling SCPs or attaching the policies changes account-wide permission ceilings.
5. Move accounts into the intended OUs manually after verifying inherited policies. This code intentionally leaves account placement under operator control.

Example import from the `terraform/` directory, after filling a local `terraform.tfvars`:

```bash
terraform import -var-file=terraform.tfvars module.organizations.aws_organizations_organization.root o-xxxxxxxxxx
```

If the `Security`, `Infrastructure`, or `Workload` OU already exists, import it into the matching address instead of letting Terraform create a duplicate. Review the state and `terraform plan` before any apply. The project intentionally has no remote backend; local state is ignored by Git and must be stored securely.

## Design limits

- Account creation/vending, OU placement, Identity Center setup/MFA, and Management-account root hardening are external prerequisites.
- One workload account and one workload VPC are configured. Adding accounts requires extending account inputs, provider profiles, SCP attachment logic, and network attachments.
- GuardDuty, Security Hub, NAT, VPN, and S3 data events are optional. The defaults avoid enabling several billable services.
- AWS Config recorders and organization aggregation are not implemented.
- No deployment, successful Terraform validation, or security behavior test is represented as completed until evidence is added under `verification/`.
