# Implementation status and completion checklist

**Reviewed:** 19 November 2026. This is a source review only. No AWS deployment or live Terraform plan was run, and no runtime claims are validated.

## Current Terraform scope

The root uses five AWS provider aliases, each mapped to a named AWS CLI profile and guarded by an expected account ID. The modules split work across those accounts:

- **Management:** Organizations/SCPs, delegated-admin registration, organization CloudTrail, and RAM organization sharing.
- **Security:** delegated GuardDuty and Security Hub configuration, the audit role, and optional finding alerts.
- **Logging:** the CloudTrail destination bucket and its bucket policy.
- **Network:** Transit Gateway, RAM share, route tables, egress VPC, optional single-AZ NAT and optional Site-to-Site VPN, plus source-account Flow Logs.
- **Workload:** one private VPC, TGW attachment, Flow Logs, and the example bounded read-only role.

The Organization and all five member accounts must already exist. The code creates three OU containers but does not create accounts or move them. Account setup, Identity Center/MFA, deployment-role permissions, Management operator role permissions, and customer-gateway configuration are prerequisites.

## Source issues addressed in this change

- Added explicit `aws.management`, `aws.security`, `aws.logging`, `aws.network`, and `aws.workload` provider wiring at the module boundaries, including a Workload alias.
- Kept annotations in SCP and boundary JSON source files; Terraform filters out root keys beginning with `_` before encoding AWS policy documents.
- Enabled `SERVICE_CONTROL_POLICY` support on the Organizations resource and documented import/reconciliation for an existing Organization and OUs.
- Added the CloudTrail ACL-check and organization-prefix write permissions to the Logging bucket policy. The organization trail is managed through the Management provider. S3 object data events are opt-in and require explicit ARNs.
- Split delegated administrator registration (Management) from GuardDuty/Security Hub account resources (Security), corrected the Security role dependency cycle, added EventBridge-to-SNS authorization and optional email subscription, and selected CIS 1.4.0.
- Added TGW route tables and associations, the workload-to-network default path only when NAT is enabled, return routes, optional VPN routing, and Flow Logs in Network and Workload accounts.
- Replaced unsupported README claims with explicit boundaries and a console evidence checklist.

## Known exclusions and decisions

| Item | Current treatment | Why it matters |
|---|---|---|
| AWS Config | Not implemented | No recorder, delivery channel, delegated admin, or aggregator is created. Remove any claim that Config is operating. |
| Multi-account expansion | One configured Workload account | Each additional workload needs provider/account inputs, policy treatment, attachments, and route design. |
| Account vending and OU placement | External/manual prerequisite | Existing accounts are not created or moved by this root module. |
| Central Flow Log archive | Not implemented | VPC Flow Logs go to CloudWatch Logs in their source accounts. |
| HA egress | Not implemented | Optional NAT is one gateway in one AZ, suitable only for a cost-aware lab. |
| Immutable audit logs | Not implemented | Bucket policy/SCP deletion denies are not S3 Object Lock and do not constrain the Organizations management account. |
| Remote Terraform state | Not configured | Local state is ignored by Git; secure it and back it up yourself. |
| Evidence and screenshots | Not present | Capture only after an actual sandbox deployment and test. |
| Editable diagrams | Planned | The design text exists; source and exported diagram files are not included. |

## Checks to complete before calling the code deployable

1. Run `terraform fmt -recursive`, `terraform init -backend=false`, and `terraform validate` in CI or locally.
2. Resolve every formatter, parser, and provider-schema error before opening a plan.
3. Configure the five profiles and verify each with `aws sts get-caller-identity --profile <profile>`.
4. Import existing Organization/OU resources as appropriate; inspect the state and plan for duplicate or destructive actions.
5. Review policy JSON after Terraform strips annotation keys; separately validate each SCP against the AWS policy grammar.
6. Plan in a dedicated organization containing only disposable lab accounts. Review every account, route, and billable resource in the plan.
7. Apply only after explicit human review. Capture console evidence, test expected allow/deny behavior, and record costs/cleanup.
8. Reconcile the README and evidence table with the actual observed result. Never label a plan as deployment proof.

The repository currently supports structural CI validation on pull requests. The workflow does not authenticate to AWS and does not generate an AWS plan.
