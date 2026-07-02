# Architecture Deep Dive

This document explains the design decisions behind every major architectural choice in this project. The goal is not to describe what was built — the code does that. The goal is to explain **why** each decision was made, what tradeoffs were accepted, and what would break first under real-world pressure.

---

## Table of Contents

1. [Account Strategy](#1-account-strategy)
2. [Network Architecture](#2-network-architecture)
3. [IAM Design](#3-iam-design)
4. [Zero Trust Implementation](#4-zero-trust-implementation)
5. [Hybrid Connectivity](#5-hybrid-connectivity)
6. [Security Observability](#6-security-observability)
7. [Blast Radius Analysis](#7-blast-radius-analysis)
8. [Attack Scenarios](#8-attack-scenarios)
9. [What I Would Change at 10x Scale](#9-what-i-would-change-at-10x-scale)

---

## 1. Account Strategy

### Decision: Multi-account over single-account with IAM separation

The temptation in most AWS setups is to use a single account and rely on IAM policies to separate environments and teams. This is the wrong model for security-critical infrastructure, for three concrete reasons:

**Blast radius.** An IAM misconfiguration, a compromised credential, or a single overly permissive policy in a single-account setup can affect all resources across all teams. In a multi-account setup, the account boundary is a hard limit that IAM cannot cross — a compromised workload account cannot touch the logging account, period.

**SCP enforcement scope.** Service Control Policies only work at the account level within AWS Organizations. You cannot attach an SCP to an IAM user or role — only to an OU or account. Multi-account is therefore a prerequisite for meaningful SCP enforcement.

**Audit integrity.** A logging account that is organizationally separate from workload accounts, with an SCP that denies bucket deletion even by account root, creates an immutable audit trail. In a single-account setup, a compromised administrative credential can delete CloudTrail logs. In this architecture, they cannot.

### OU Structure

```
Root
├── Management Account          (billing, Organizations control, no workloads)
├── Security OU
│   └── Security Account        (GuardDuty admin, Security Hub aggregator)
├── Infrastructure OU
│   ├── Logging Account         (immutable CloudTrail, VPC Flow Logs)
│   └── Network Account         (Transit Gateway, centralized egress)
└── Workload OU
    └── Workload Account(s)     (application resources, strict permission boundaries)
```

### Why the Management Account runs no workloads

The management account has elevated trust in AWS Organizations — it can apply SCPs, create accounts, and access billing across the entire organization. Running workloads here would mean that a compromised application in the management account has organizational-level access. The management account exists solely for organizational control and billing. Nothing else runs there.

---

## 2. Network Architecture

### Decision: No public subnets in workload accounts

Every workload VPC in this architecture uses private subnets only. There are no internet gateways attached to workload VPCs. All outbound internet traffic routes through a centralized NAT Gateway in the Network account via Transit Gateway.

**Why this matters:** Removing the internet gateway from workload accounts eliminates an entire class of attack surface. Even if a security group is misconfigured to allow inbound 0.0.0.0/0, there is no path for external traffic to reach the instance — the route simply does not exist.

### Decision: Transit Gateway over VPC Peering

VPC peering does not scale. At 10 VPCs, you need up to 45 peering connections. At 50 VPCs, it becomes unmanageable. Transit Gateway acts as a hub, allowing all VPCs to connect through a single managed router with per-account route table isolation.

More importantly, Transit Gateway route tables allow fine-grained control over which accounts can reach which other accounts. In this architecture:

- Workload accounts can reach the Network account (for egress)
- Workload accounts **cannot** reach each other directly
- The Security account has read access to VPC Flow Logs but cannot initiate connections into workload VPCs
- The Logging account is isolated — no inbound connectivity from any account

### Decision: Security Groups as primary control, NACLs as secondary

Security Groups are stateful and easier to reason about — they track connection state, so you only need to allow inbound traffic and return traffic is automatically permitted. NACLs are stateless and apply to subnets rather than resources.

In this architecture, NACLs serve as a blunt backstop — they enforce subnet-level rules that block known-bad traffic regardless of Security Group configuration. The principle is defense-in-depth: a Security Group misconfiguration does not automatically result in a breach because the NACL catches it at the subnet boundary.

---

## 3. IAM Design

### Decision: Permission boundaries on all roles in workload accounts

An IAM permission boundary is a managed policy that sets the maximum permissions any role in that account can have — regardless of what inline policies or managed policies are attached. Even if a developer creates a role with `AdministratorAccess`, if the permission boundary doesn't include that action, it doesn't work.

This closes a critical gap: **IAM escalation within an account.** Without permission boundaries, a role that has `iam:CreateRole` and `iam:AttachRolePolicy` can create a new role with full administrator access. With a permission boundary that doesn't include IAM write actions, this escalation path is closed.

The permission boundary in this project:
- Allows specific service actions needed for workload operation
- Explicitly denies all IAM write actions
- Explicitly denies all Organizations actions
- Explicitly denies disabling GuardDuty, CloudTrail, or Security Hub

### Decision: Role assumption chains over direct IAM user access

No IAM users with long-lived access keys exist in this architecture. Access follows a chain:

```
Developer (IAM Identity Center / SSO)
    │
    ▼ sts:AssumeRole (with MFA condition)
Management Account Role
    │
    ▼ sts:AssumeRole (cross-account, with aws:PrincipalOrgID condition)
Workload Account Role (scoped to specific service)
    │
    ▼ Maximum 1-hour session
Resource Access
```

**Why this matters:** Long-lived access keys are the single most common source of AWS credential compromise. Role assumption chains produce temporary credentials with a short TTL. A leaked credential from a role assumption expires in at most one hour. A leaked IAM user access key is valid until manually rotated.

### Cross-account trust conditions

Every cross-account role trust policy includes:

```json
"Condition": {
  "StringEquals": {
    "aws:PrincipalOrgID": "o-XXXXXXXXXX"
  },
  "Bool": {
    "aws:MultiFactorAuthPresent": "true"
  }
}
```

`aws:PrincipalOrgID` ensures only principals from within this AWS Organization can assume the role — external accounts are categorically excluded, even if they somehow know the role ARN. `aws:MultiFactorAuthPresent` enforces MFA at the point of role assumption, not just at login.

---

## 4. Zero Trust Implementation

Zero Trust is not a product or a checklist. It is a security model built on three principles: never trust implicitly, always verify explicitly, and assume breach has already occurred. Here is how each principle maps to concrete implementations in this architecture.

### Never trust, always verify

Every cross-account action requires explicit verification via IAM conditions. There are no trust relationships that say "trust everything from account X" — every trust policy has conditions on MFA presence, organization membership, and in some cases source IP (VPN requirement for sensitive roles).

### Least privilege everywhere

The combination of SCPs (maximum permissions at the organization level) and permission boundaries (maximum permissions at the account level) creates two independent enforcement layers. A role cannot exceed what its permission boundary allows, and a permission boundary cannot exceed what the SCP allows. This is defense-in-depth applied to IAM.

### Assume breach

The blast radius design assumes that any workload account can be compromised at any time. The architecture is designed so that a fully compromised workload account gives an attacker:

- Access to resources in that account only
- No ability to modify logging (SCP-protected)
- No ability to disable GuardDuty or Security Hub (SCP-protected + permission boundary)
- No ability to reach other accounts (TGW route table isolation)
- Full visibility to the security team in real time (GuardDuty + CloudTrail already running)

### Just-in-time access

Role sessions in workload accounts are set to a maximum of 1 hour (`DurationSeconds: 3600`). There are no persistent credentials. Access is obtained when needed, scoped to what is needed, and expires automatically.

---

## 5. Hybrid Connectivity

### Topology

```
On-Premises (simulated)                    AWS
EC2 acting as customer gateway
├── BGP ASN: 65000               ◄──── Site-to-Site VPN ────► Transit Gateway
├── Static routing to 10.0.0.0/8           Network Account VPC
└── Tunnel: IKEv2, AES-256                 ├── Route table: on-prem → workload VPCs
                                            └── Workload VPCs (private only)
```

### Decision: Terminate VPN at Transit Gateway, not at VPC VPN Gateway

Terminating the VPN at the Transit Gateway rather than at individual VPC Virtual Private Gateways means on-premises connectivity is centralized. Adding a new workload account means adding a Transit Gateway attachment and a route table entry — not configuring a new VPN tunnel.

This is the architecture pattern that scales. At one workload account, both approaches work. At twenty workload accounts, only the Transit Gateway approach is manageable.

### What on-premises traffic can reach

On-premises traffic enters via the VPN, terminates at the Transit Gateway, and is routed per Transit Gateway route tables. In this architecture:

- On-premises **can** reach workload VPC private subnets (for simulated application access)
- On-premises **cannot** reach the logging account (route does not exist)
- On-premises **cannot** reach the security account (route does not exist)
- All on-premises to AWS traffic is logged via VPC Flow Logs

---

## 6. Security Observability

### Detection pipeline

```
Event Source          →    Collection           →    Aggregation          →    Action
─────────────────────────────────────────────────────────────────────────────────────
API calls (all accts) → CloudTrail (org trail) → S3 (logging account)   → Athena queries
Network traffic       → VPC Flow Logs           → CloudWatch Logs        → Metric alarms
Threat intelligence   → GuardDuty (all accts)  → Security Hub (sec acct)→ EventBridge rules
Config changes        → AWS Config             → Security Hub            → SNS alerts
```

### Why GuardDuty delegated admin lives in the Security account

GuardDuty findings from all accounts aggregate to the Security account, which is organizationally separate from all workload accounts. An attacker who fully compromises a workload account cannot suppress GuardDuty findings from that account — the findings are already in a separate account they do not control.

This is the most important design decision in the observability layer. Detection that can be disabled by an attacker is not detection.

### Sample detection scenario

**Scenario:** Credential exfiltration and unauthorized API calls from external IP.

**What happens:**
1. GuardDuty generates `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration` finding
2. Finding aggregates to Security account Security Hub within minutes
3. CloudTrail records the exact API calls, source IP, and resource ARNs
4. EventBridge rule triggers SNS notification to security team
5. VPC Flow Logs show network path of the exfiltration attempt

**What the attacker cannot do:**
- Delete CloudTrail logs (SCP: `deny-disable-cloudtrail`)
- Suppress GuardDuty findings (findings are in the Security account)
- Persist beyond session expiry (maximum 1-hour role sessions)
- Reach other accounts (TGW route table isolation)

---

## 7. Blast Radius Analysis

| Compromised Account | What attacker can access | What is protected |
|---|---|---|
| Workload account | Resources in that account only | All other accounts, logging, security tooling |
| Network account | Transit Gateway routing | Cannot modify SCPs, cannot reach logging account |
| Security account | GuardDuty/Security Hub read data | Cannot modify workload resources, cannot delete logs |
| Logging account | (Isolated — no inbound paths) | Everything |
| Management account | Organizational control (highest risk) | Protected by root MFA, no workloads running here |

The management account compromise scenario is the most severe. Mitigation is simple: the management account has no IAM users with long-lived credentials, MFA is enforced on root, and all human access goes via IAM Identity Center with time-limited sessions.

---

## 8. Attack Scenarios

### Scenario A: Compromised EC2 instance credentials

An attacker exploits a vulnerability in a workload application and retrieves the EC2 instance role credentials via the metadata service.

**What they get:** Temporary credentials for the specific IAM role attached to that EC2 instance, scoped by the permission boundary to specific service actions in that account only.

**What they cannot do:**
- Assume roles in other accounts (trust policies require `aws:PrincipalOrgID` + MFA, which instance credentials cannot satisfy)
- Disable monitoring (SCPs block GuardDuty and CloudTrail modification)
- Reach other accounts (no network path via TGW route tables)

**Detection:** GuardDuty `InstanceCredentialExfiltration` finding generated within minutes if credentials are used from an IP outside the VPC CIDR. CloudTrail records all API calls.

**Why IMDSv2 matters here:** The SCP `enforce-imdsv2.json` requires IMDSv2 on all EC2 instances. IMDSv2 requires a session token obtained via a PUT request, which SSRF attacks cannot perform. This eliminates the most common path for metadata credential theft.

---

### Scenario B: Malicious SCP modification attempt

An attacker with workload account compromise attempts to remove the `deny-disable-cloudtrail` SCP to cover their tracks.

**What happens:** The SCP modification requires Organizations API calls from the management account. The workload account has no Organizations permissions (SCP-blocked + permission boundary). The attempt generates a CloudTrail `AccessDenied` event, which triggers a GuardDuty finding.

---

## 9. What I Would Change at 10x Scale

At 50+ accounts, several manual processes in this architecture become bottlenecks. Here is what changes and why.

### AWS Control Tower — account vending

In this project, accounts are created manually and configured via Terraform. At scale, this is untenable. Control Tower automates account creation with standardized guardrails, logging, and security baselines via Account Factory. New accounts are production-ready in minutes.

**Tradeoff accepted by not using it now:** Control Tower has a high setup cost and opinionated structure. For a demonstration architecture, direct Organizations + Terraform control is cleaner and more transparent.

### IAM Identity Center replacing role assumption chains

At scale, managing cross-account role assumption chains for dozens of teams across 50+ accounts becomes a maintenance burden. IAM Identity Center provides a centralized SSO entry point with permission sets that are assigned to users/groups and propagated across all accounts automatically.

**Tradeoff accepted by not using it now:** IAM Identity Center setup requires additional configuration and an identity source. The manual role assumption chain in this project is more explicit and educational for demonstrating the underlying mechanics.

### Centralized IPAM

At scale, manually managing VPC CIDR allocations across 50+ accounts leads to overlapping address spaces and routing failures. AWS IPAM provides centralized IP address management with automatic allocation and conflict detection.

### AWS Network Firewall at the egress VPC

Security Groups and NACLs provide stateful and stateless filtering but not deep packet inspection. At scale, centralized egress through a Network Firewall in the Network account adds layer-7 inspection, domain-based filtering, and intrusion detection without per-workload configuration.

### Macie for data classification in the logging account

At scale, the S3 bucket in the logging account may contain sensitive data from across the organization. Macie provides automated PII detection and data classification, ensuring the logging account itself is not a compliance risk.

---

*Last updated: April 2026*  
*Author: Ilyas — Cloud Security Engineering, ENSA Oujda*
