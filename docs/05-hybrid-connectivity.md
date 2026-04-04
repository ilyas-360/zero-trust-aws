# 05 — Hybrid Connectivity

## Architecture

On-premises environment is simulated using an EC2 instance configured as a customer gateway device. This replicates a real enterprise scenario where physical on-premises infrastructure connects to AWS without going through the public internet.

```
On-Premises (simulated)                         AWS
──────────────────────                          ──────────────────────────────
EC2 Customer Gateway                            Network Account
├── BGP ASN: 65000               ◄── VPN ───►  Transit Gateway
├── Tunnel 1: IKEv2, AES-256-GCM               ├── TGW Route Table
├── Tunnel 2: IKEv2, AES-256-GCM (redundant)   │   ├── on-prem → workload VPC
└── Routes advertised: 192.168.0.0/16          └── Workload VPC attachment
```

## Why Terminate VPN at Transit Gateway

Terminating the VPN at the Transit Gateway rather than at individual VPC Virtual Private Gateways means on-premises connectivity is centralized. Adding a new workload account requires adding a TGW route table entry — not configuring a new VPN tunnel.

At one account, both approaches work. At twenty accounts, only TGW termination is manageable.

## What On-Premises Can Reach

On-premises traffic enters via VPN, terminates at Transit Gateway, and is routed per TGW route tables:

| Destination | Accessible from On-Prem | Reason |
|---|---|---|
| Workload VPC private subnets | Yes | Explicit TGW route |
| Logging account | No | No TGW route exists |
| Security account | No | No TGW route exists |
| Management account | No | No TGW route exists |
| Internet (via AWS) | No | No NAT path from on-prem |

On-premises to AWS traffic is logged via VPC Flow Logs. Any unexpected traffic patterns from the on-prem CIDR range trigger GuardDuty findings.

## Redundancy

Two VPN tunnels are configured between the customer gateway and Transit Gateway. AWS manages one tunnel per availability zone. If one tunnel fails, traffic automatically fails over to the second tunnel with no configuration change required. This matches the real enterprise pattern where VPN redundancy is a baseline requirement.

## Security Controls on Hybrid Traffic

On-premises traffic that enters AWS through the VPN is treated as untrusted by default:

- Security Groups in workload VPCs restrict which resources on-prem can reach
- VPC Flow Logs capture all traffic including source IPs from on-prem CIDR
- GuardDuty monitors for anomalous traffic patterns from the VPN source range
- On-prem hosts cannot assume AWS IAM roles — they have no credentials path
