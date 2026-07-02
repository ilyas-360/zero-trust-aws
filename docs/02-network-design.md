# 02 — Network Design

## Core Principle: No Public Subnets in Workload Accounts

Every workload VPC uses private subnets only. There is no internet gateway attached to any workload VPC. All outbound internet traffic routes through a centralized NAT Gateway in the Network account via Transit Gateway.

This removes an entire class of attack surface. Even a completely open security group (0.0.0.0/0 inbound) in a workload account cannot expose a resource to internet traffic — the route simply does not exist. The misconfiguration has no effect.

## Transit Gateway Over VPC Peering

VPC peering is a direct, non-transitive connection between two VPCs. At small scale it works. At 10+ VPCs it requires up to 45 peering connections and becomes unmanageable. More importantly, VPC peering has no central point to enforce routing policy.

Transit Gateway acts as a hub router. All VPCs attach to it and traffic is routed per Transit Gateway route tables. This enables:

- Per-account route table isolation — workload accounts can only reach Network account, not each other
- Centralized egress — all internet traffic exits through a single inspectable point
- Simple scaling — adding a new account means adding one TGW attachment, not N peering connections

## Micro-Segmentation

Security Groups are the primary network control — they are stateful and applied per resource. NACLs are applied at the subnet level as a stateless backstop. The principle is defense-in-depth: a Security Group misconfiguration does not automatically result in a breach because the NACL enforces subnet-level rules independently.

Workload subnets are separated by function. Application tier subnets cannot communicate directly with data tier subnets — traffic must pass through a Security Group boundary that enforces least-privilege network access.
