# 02 — Network Design

> **Status: Terraform target for one workload account.** NAT and VPN are optional; NAT is disabled and VPN omitted by default. The module has not been applied or connectivity-tested.

## Account and VPC scope

The root Terraform configuration manages one Network account VPC and one Workload account VPC. The workload VPC has two private subnets and no Internet Gateway. The Network VPC has a public subnet reserved for egress NAT and private subnets for its Transit Gateway attachment.

## Transit Gateway sharing and routing

The Network account owns a Transit Gateway shared with the AWS Organization through AWS RAM. Shared VPC attachments are not automatically accepted; the Network account explicitly accepts the Workload attachment. Automatic route-table association and propagation are disabled.

Three TGW route tables are defined:

| Table | Association | Intended routes |
|---|---|---|
| Workload | Workload VPC attachment | Default route to the Network VPC only when NAT is enabled; optional learned on-prem routes when VPN is configured |
| Egress | Network VPC attachment | Workload CIDR to the Workload attachment |
| On-prem | VPN attachment when enabled | Workload CIDR to the Workload attachment |

The one-AZ NAT option minimizes lab cost and is not highly available. With it disabled, the workload VPC has no default internet route; the Terraform avoids creating a default route that would blackhole at the TGW.

## Flow logs and segmentation limits

The module enables VPC Flow Logs for the Network and Workload VPCs and writes each to CloudWatch Logs in its own account. It does not centralize those flow logs in the Logging account. The project does not define custom application Security Groups, NACLs, or tier-by-tier micro-segmentation rules. Those require a real test workload and documented allowed flows.

Before enabling NAT, review current AWS pricing and the route-table plan. Before claiming connectivity, test both the expected path and a denied path and record the route tables, source/destination CIDRs, and Flow Log evidence.
