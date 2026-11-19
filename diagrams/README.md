# Architecture Diagrams

This folder currently contains this index only; diagram image files and editable source files have **not** been added. The diagrams below are the planned visuals. Add them after the architecture and Terraform account boundaries agree, so the visual does not imply components that the implementation lacks.

| Planned file | Content |
|---|---|
| `account-structure.png` and `account-structure.drawio` | Management account, OUs, member accounts, and SCP attachment scope |
| `network-topology.png` and `network-topology.drawio` | VPCs, subnets, route tables, Transit Gateway attachments, and permitted routes |
| `identity-flow.png` and `identity-flow.drawio` | Authentication, role assumption, session duration, and permission boundary |
| `hybrid-connectivity.png` and `hybrid-connectivity.drawio` | Customer gateway, Site-to-Site VPN, Transit Gateway, and reachable prefixes |
| `security-observability.png` and `security-observability.drawio` | Organization CloudTrail, log destination, GuardDuty administration, and Security Hub aggregation |

Create and export diagrams with [diagrams.net](https://app.diagrams.net/). Keep both the editable `.drawio` source and a readable PNG. Label each diagram **Target design** until it matches a deployed and verified environment. Use a legend for “deployed,” “planned,” and “external” components, and do not draw a connection unless its route or service integration exists.
