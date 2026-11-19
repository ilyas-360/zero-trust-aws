# Zero Trust AWS Lab — Architecture and Threat Model

> **Status (19 November 2026):** This is the design represented by the Terraform source. The repository has no evidence of an AWS deployment or runtime test. Review the complete plan in a dedicated sandbox before applying.

## Scope

Terraform expects an existing AWS Organization with five existing accounts. It manages one example Workload account/VPC, not an arbitrary fleet. It creates OU containers but does not create accounts or move accounts into OUs. IAM Identity Center, human MFA, root account hardening, account vending, and the Management operator's permissions are external prerequisites.

| Account | Terraform responsibilities |
|---|---|
| Management | Organizations/SCPs, OU containers, delegated-admin registration, organization CloudTrail, RAM org sharing |
| Security | Security audit role, GuardDuty, Security Hub, optional EventBridge/SNS alerting |
| Logging | Versioned, encrypted CloudTrail S3 bucket, public-access block, bucket policy |
| Network | Shared TGW, route tables, Network VPC, optional NAT/VPN, Network VPC Flow Logs |
| Workload | One private VPC, TGW attachment, Workload Flow Logs, bounded read-only audit role |

The five Terraform providers use local AWS CLI profiles, separately guarded by expected account IDs. The matching operator must have service-specific permissions in each account. A wrong profile should fail the provider account-ID check.

## Organization guardrails

The Organizations module enables SCP policy type support and creates five guardrails: root API use, CloudTrail modification, non-approved Regions, non-IMDSv2 EC2 launches, and deletion of log-bucket objects/buckets matching the project prefix. Terraform strips top-level underscore-prefixed annotations from JSON before sending policy documents to AWS and injects the configured allowed Regions.

Guardrails attach to three OU containers and directly to four configured member accounts. Direct account attachments protect the current configured accounts regardless of their OU placement; OU attachments provide inheritance if an operator later moves accounts. SCPs do not grant permissions and do not constrain the Organizations management account. Import existing Organizations, OUs, policies, or attachments before applying; inspect all permission changes.

## Network paths

The Workload VPC has two private subnets and no Internet Gateway. The Network account owns a Transit Gateway shared within the Organization. Auto-acceptance and automatic route-table association/propagation are disabled. Three TGW route tables separate workload, egress, and optional VPN paths.

When NAT is disabled (default), Terraform creates no Workload default route to the TGW, avoiding a blackhole route. When enabled, the path is:

1. Workload subnet default route → TGW.
2. Workload TGW route table default → Network VPC attachment.
3. Network VPC attachment subnet default route → single-AZ NAT Gateway.
4. NAT public subnet default route → Internet Gateway.
5. Specific return routes for Workload CIDR → TGW → Workload attachment.

The NAT option is a lab design with one gateway in one Availability Zone. It is not highly available, and costs continue while the gateway exists. The optional VPN uses a customer-gateway public IP and BGP ASN supplied by the operator. The external device, secrets, firewall rules, and configuration are not managed here. A created VPN resource or route is not proof of a working tunnel.

VPC Flow Logs write to CloudWatch Logs in each source account. They are not centrally archived in the Logging account. No application-specific Security Groups, NACLs, or micro-segmentation rules are defined.

## Identity and cross-account access

The example access chain is:

```text
Management IAM Identity Center role
  → SecurityAssumeWorkloadReadRole (Security account; max session 1 hour)
  → WorkloadSecurityReadRole (Workload account; max session 1 hour)
  → scoped security-evidence reads
```

Trust is limited to the configured Management role, the Security role, and the Organization ID. The workload role carries a managed permission boundary and read policy. This is one example audit role only; the boundary is not attached to all workload roles. The Management operator permission set must independently allow the first `sts:AssumeRole` call.

Human MFA is an Identity Center or upstream IdP requirement. The trust policies do not evaluate `aws:MultiFactorAuthPresent`, which AWS documents as absent for federated identities. Terraform does not configure MFA policy or session lifetime in Identity Center.

## Logging and detection

A multi-Region organization CloudTrail is created from Management and writes to a Logging-account bucket. The bucket has versioning, SSE-S3 default encryption, public access blocking, a CloudTrail ACL check/write policy scoped to the Organization prefix, and explicit deletion denies. A member-account SCP adds a separate matching-name guardrail. The Management account is outside SCP scope and the bucket does not use S3 Object Lock, so logs are **deletion-protected**, not immutable.

CloudTrail management events are selected. S3 object data events are off by default and are included only for explicitly configured object ARNs. These events can add cost.

GuardDuty and Security Hub run only in the configured primary Region when enabled; the code does not enable those services in every allowed Region. GuardDuty's Security-account delegated admin sends severity-7-or-higher findings to an EventBridge rule and SNS topic. Email is optional and requires subscription confirmation. Security Hub subscribes to AWS Foundational Security Best Practices and CIS 1.4.0. No AWS Config recorder, delivery channel, or aggregator is included.

## Threat assumptions and limits

| Threat | Intended control | Remaining limit |
|---|---|---|
| Workload operator attempts to stop CloudTrail | SCP attached to member account; separate logging account and bucket policy | Management account is not SCP-constrained; no Object Lock; control behavior not tested |
| Workload role attempts IAM privilege escalation | Permission boundary on the example audit role | Other roles are not automatically bounded; a more privileged administrator can change IAM |
| Workload instance requires public inbound access | No Internet Gateway on Workload VPC; private subnets | No application workload or custom ingress/egress rules are created |
| Egress or on-premises route leaks | Separate TGW route tables and explicit static/propagated paths | Routing is not validated; one workload account; VPN endpoint is external; NAT is single-AZ |
| Detection service disabled or missing in another Region | Optional delegated service setup in one configured Region | No all-Region GuardDuty/Security Hub deployment, AWS Config, or proven finding delivery |
| Terraform targets the wrong AWS account | Named profiles plus provider `allowed_account_ids` | Operator still must verify identities and plan before apply |

## Cost and cleanup

NAT Gateway, Transit Gateway, Site-to-Site VPN, CloudTrail data events, CloudWatch log ingestion/retention, GuardDuty, and Security Hub may incur charges. Optional NAT, VPN, GuardDuty, Security Hub, and data events are disabled by default. Review current pricing and an actual plan before enabling them. Keep Terraform state private, record resource IDs, and verify all billable resources are removed during sandbox cleanup.

See [`docs/00-implementation-roadmap.md`](docs/00-implementation-roadmap.md) for code status and [`verification/README.md`](verification/README.md) for exact setup, plan review, test, and screenshot steps.
