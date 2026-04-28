# Diagrams

Architecture diagrams for the Zero Trust multi-account AWS environment.

## Diagrams in This Folder

| File | Description |
|---|---|
| `account-structure.png` | AWS Organizations tree — Management account, OUs, accounts, SCP attachments |
| `network-topology.png` | VPC layout per account, Transit Gateway hub, private subnet isolation |
| `zero-trust-flow.png` | Request flow — authentication → role assumption chain → permission boundary → resource |
| `hybrid-connectivity.png` | On-premises EC2 customer gateway → Site-to-Site VPN → Transit Gateway → workload VPCs |
| `security-observability.png` | Detection pipeline — CloudTrail + GuardDuty + VPC Flow Logs → Security Hub |

## Tools Used

All diagrams created with [draw.io](https://app.diagrams.net/) —   free, no account required. Exported as PNG for GitHub rendering. Source `.drawio` files included for editability.

*Diagrams being added as architecture is finalized during week of April 6, 2026.*
