# 07 — Tradeoffs and Scalability

## What This Architecture Optimizes For

This architecture prioritizes transparency and explicit control over operational convenience. Every resource is visible in Terraform code. Every trust relationship is explicitly stated in policy JSON. Every design decision has a documented reason.

The tradeoff: manual process. Creating a new account, adding it to the right OU, applying permission boundaries, connecting it to the Transit Gateway — these steps are done manually or via targeted Terraform runs. At five accounts, this is manageable. At fifty accounts, it becomes a bottleneck.

## What Changes at 10x Scale

### AWS Control Tower — Account Vending

At 50+ accounts, manual account creation is the primary bottleneck. Control Tower provides an Account Factory that provisions new accounts from a template in minutes: correct OU placement, baseline SCPs, logging configuration, and security tooling enabled automatically.

**Tradeoff accepted by not using it now:** Control Tower has significant setup complexity and an opinionated account structure that is harder to customize. For a demonstration architecture, direct Organizations + Terraform control is more transparent and educational.

### IAM Identity Center — Centralized SSO

At scale, managing cross-account role assumption chains for dozens of teams across 50+ accounts becomes a maintenance burden. IAM Identity Center provides a single SSO entry point. Permission sets are defined once and assigned to users or groups, then automatically provisioned across all accounts.

**Tradeoff accepted by not using it now:** The manual role chain in this architecture makes the underlying mechanics explicit — which is valuable for understanding how cross-account trust actually works. IAM Identity Center abstracts this away.

### Centralized IPAM

At scale, manually assigning VPC CIDR blocks across 50+ accounts leads to overlapping address spaces and routing failures. AWS IPAM provides centralized IP address management with automatic allocation and conflict detection.

**Tradeoff accepted by not using it now:** Five accounts with carefully chosen non-overlapping CIDRs (10.0.0.0/16 through 10.4.0.0/16) is manageable without IPAM.

### AWS Network Firewall

Security Groups and NACLs provide stateful and stateless packet filtering but not deep packet inspection. At scale, a Network Firewall deployed in the egress VPC (Network account) provides layer-7 filtering: domain-based egress control, intrusion detection signatures, and TLS inspection.

**Tradeoff accepted by not using it now:** Network Firewall adds ~$400-600/month in baseline cost — not appropriate for a demonstration architecture.

### Macie for Data Classification

At scale, the S3 bucket in the Logging account contains sensitive API call data from across the organization. Macie provides automated PII detection and data classification — ensuring the logging infrastructure itself does not become a compliance risk.

## What Would Break First at 10x Scale

In order of urgency:

1. **Account provisioning** — manual process becomes the bottleneck immediately. Control Tower first.
2. **CIDR management** — overlapping VPC CIDRs cause silent routing failures. IPAM second.
3. **Access management** — permission set changes needing manual role updates across 50 accounts. IAM Identity Center third.
4. **Egress visibility** — Security Groups cannot inspect domain names or TLS SNI. Network Firewall fourth.

## What Would NOT Break

The core Zero Trust properties — SCPs, permission boundaries, cross-account GuardDuty, immutable CloudTrail — all scale to hundreds of accounts without architectural changes. These are organizational-level controls that apply automatically to new accounts via OU membership. The foundation is solid at 10x scale. Only the operational tooling around it needs upgrading.
