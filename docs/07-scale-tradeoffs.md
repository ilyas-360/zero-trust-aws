# 07 — Tradeoffs and Scaling Limits

> **Status: design notes.** The Terraform root currently supports five named account profiles and one Workload account/VPC. The scaling items below are future design considerations, not deployed services.

## Current scope and tradeoffs

- **One workload account:** provider aliases cannot be selected dynamically for arbitrary account lists. This root intentionally defines one workload provider/account; extending to more accounts requires explicit module instances or a redesigned account map/provider strategy.
- **Direct Organizations management:** useful for learning SCP and OU behavior, but this repository does not create new AWS accounts or manage Control Tower.
- **Single-AZ NAT option:** lower fixed lab cost, no availability-zone redundancy. It is disabled by default.
- **Optional Site-to-Site VPN:** Terraform creates AWS-side resources only. A customer-gateway appliance and its configuration are external prerequisites.
- **Per-account Flow Logs:** CloudWatch destinations stay in their source accounts. Central log subscription/aggregation is not included.
- **No application micro-segmentation:** application security groups, NACL rules, and workload tiers need a concrete service/test workload.
- **No AWS Config:** the current Terraform does not create Config recorders or aggregators.

## Sensible extensions after the core works

1. Use AWS Control Tower or an account-vending workflow for consistent account creation and OU placement.
2. Add IPAM and CIDR validation before adding more VPCs.
3. Add an application workload with narrowly scoped security groups and explicit allow/deny connectivity tests.
4. Centralize VPC Flow Logs in the Logging account and verify cross-account delivery.
5. Consider multi-AZ NAT, AWS Network Firewall, and redundant VPN/customer-gateway devices after documenting the cost and operational tradeoffs.
6. Define a Terraform state backend with encryption, versioning, locking, and restricted access before collaborating on shared state.

The project should claim only properties that the current code and captured evidence demonstrate. A future extension should include its own plan, test, screenshot, and teardown evidence.
