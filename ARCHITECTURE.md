# Architecture Deep Dive

This document complements the [README](README.md) with the deeper "why" behind the design — the kind of detail that matters when defending the architecture in a security review or operating it during an incident.

## Contents

- [Design Goals](#design-goals)
- [Threat Model](#threat-model)
- [Network Topology](#network-topology)
- [Routing Logic](#routing-logic)
- [Firewall Policy Model](#firewall-policy-model)
- [TLS Inspection: When and When Not](#tls-inspection-when-and-when-not)
- [Logging and Detection](#logging-and-detection)
- [Failure Modes](#failure-modes)
- [Scaling Considerations](#scaling-considerations)
- [Compliance Mapping](#compliance-mapping)

---

## Design Goals

| Goal | How the design satisfies it |
|------|------------------------------|
| **Single enforcement point** | All spoke egress is routed through one inspection VPC via TGW |
| **Default deny unless inspected** | TGW routes never bypass the firewall; stateless rule order is `STRICT_ORDER` |
| **Original source IP preserved** | Firewall sits *before* NAT, not after |
| **High availability** | Multi-AZ NFW endpoints, NAT GWs, TGW attachments; AZ-affine routing |
| **Observable** | NFW alert + flow logs to CloudWatch + S3; correlated with VPC and TGW Flow Logs |
| **Reusable** | Modular Terraform; spoke module is parameterized |
| **Compliance evidence** | Centralized logs satisfy PCI-DSS Req 1, 10; ISO 27001 A.13; HIPAA §164.312 |

---

## Threat Model

We use STRIDE applied to the egress path:

| Threat | Example | Control in this design |
|--------|---------|------------------------|
| **S**poofing | Workload spoofs a different account's traffic | TGW attachment isolation; per-VPC route tables |
| **T**ampering | In-flight modification of egress traffic | Encrypted transport; logged at ingress and inspection layers |
| **R**epudiation | Workload denies making an outbound call | Centralized NFW + VPC Flow Logs with original src IP |
| **I**nformation disclosure | Data exfiltration via DNS / QUIC / unsanctioned SaaS | Suricata rules; QUIC drop; domain allowlist |
| **D**enial of Service | Misconfigured rule blocks legitimate traffic | Staged rollout; alert-only mode; canary spokes |
| **E**levation of privilege | Compromised workload pivots to inspection VPC | Inspection VPC has no inbound paths from spokes except via TGW; tight SG/NACL |

### Trust boundaries

```
┌──── Spoke Account ────┐  ┌──── Network Account ────┐  ┌── Internet ──┐
│                       │  │                          │  │              │
│  Workload (low trust) │──│ TGW Attachment (medium) ──│ Firewall (high)│ ─→ FQDN
│                       │  │   Inspection VPC (high)  │  │              │
└───────────────────────┘  └──────────────────────────┘  └──────────────┘
```

Each boundary crossing is policy-enforced.

---

## Network Topology

### Inspection VPC layout (per AZ)

| Subnet | Purpose | Route table |
|--------|---------|-------------|
| `tgw-attach-subnet` | TGW ENI lands here | `0.0.0.0/0 → firewall endpoint` |
| `firewall-subnet` | NFW endpoint (VPCE) | `0.0.0.0/0 → NAT GW (same AZ)` |
| `nat-subnet` | NAT Gateway | `0.0.0.0/0 → IGW`; spoke CIDRs → TGW |

CIDR plan example: `100.64.0.0/16` for the inspection VPC keeps it out of RFC1918 collision territory across business units.

### Spoke VPC layout (per AZ)

| Subnet | Route table |
|--------|-------------|
| `private-subnet` | `0.0.0.0/0 → TGW` |
| `tgw-attach-subnet` | local only |

Spokes have **no IGW** and **no NAT GW** — internet egress is structurally impossible without traversing the inspection VPC.

---

## Routing Logic

The non-obvious bits:

### Forward path
1. EC2 in Spoke A AZ-1 sends `→ 1.1.1.1`
2. Spoke A subnet RT: default → TGW
3. TGW spoke RT: default → Inspection VPC attachment
4. Inspection VPC TGW-attach RT: default → NFW endpoint (AZ-1)
5. NFW inspects, allows
6. Firewall subnet RT: default → NAT GW (AZ-1)
7. NAT GW subnet RT: default → IGW
8. Egress to internet

### Return path
9. Internet → IGW → NAT GW (translated back to AZ-1 NAT EIP)
10. NAT subnet RT: spoke CIDRs → TGW
11. TGW inspection RT: route to Spoke A
12. Returns to EC2

If step 4 routed to a *different AZ's* NFW endpoint, the return packet would arrive at the AZ-1 firewall endpoint with no flow state — **dropped by the stateful engine**. AZ-affine routing is non-negotiable.

---

## Firewall Policy Model

The policy is structured in tiers, evaluated in this order:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Stateless rules                                          │
│    • Drop QUIC (UDP/443)                                    │
│    • Drop suspicious source ports                           │
│    • Forward all others to stateful                         │
├─────────────────────────────────────────────────────────────┤
│ 2. Stateful rules (STRICT_ORDER)                            │
│    a. Pass: corporate allowlist (TLS SNI / HTTP Host)       │
│    b. Drop: known-bad TLDs / category lists                 │
│    c. Drop: high-risk file downloads (.exe, .dll over HTTP) │
│    d. Drop: IDS signatures (custom Suricata)                │
│    e. Default: drop                                         │
└─────────────────────────────────────────────────────────────┘
```

### Why not just rely on managed rule groups?

AWS-managed rule groups are excellent for breadth (threat intel feeds), but:
- They evolve outside your change-control process
- They don't know your business context (allowed SaaS, dev tooling)
- Their default action behavior can surprise you under `DEFAULT_ACTION_ORDER`

The pattern in this repo: **managed rule groups for threat intel, custom rule groups for policy**.

---

## TLS Inspection: When and When Not

TLS inspection in AWS Network Firewall (released 2023) decrypts outbound TLS, inspects payload via Suricata, and re-encrypts. It requires:

- A CA certificate in ACM whose **private key** is accessible to NFW
- That CA's public cert distributed to all clients (workloads) as trusted
- A revocation strategy (your CA is now in the data path)

### Where it works

- ✅ Internal-to-internal HTTPS where you control both ends
- ✅ Inspecting workload traffic to general-purpose web destinations
- ✅ DLP/sensitive content detection (when paired with Suricata `file_data`)

### Where it breaks (operational reality)

- ❌ Mobile SDKs and banking apps with **certificate pinning** — they reject any cert not from their pinned CA, regardless of trust
- ❌ Some Microsoft 365 endpoints (Microsoft explicitly publishes a *do-not-inspect* list)
- ❌ Apple Push Notification Service, App Store binaries
- ❌ Mutual TLS (mTLS) flows — client cert presentation breaks under MITM
- ❌ HTTP/3 (QUIC) entirely

### Recommended posture

| Egress destination | Approach |
|--------------------|----------|
| General web browsing | Domain allowlist via SNI/Host (no decrypt) |
| Approved SaaS | Domain allowlist; do-not-inspect list maintained |
| Sensitive data flows | TLS inspection + DLP rules |
| Mobile / pinned apps | Bypass list; rely on egress restriction by FQDN only |
| Untrusted egress | Block entirely |

---

## Logging and Detection

Three log streams, three purposes:

| Stream | Source | Purpose | Retention |
|--------|--------|---------|-----------|
| **NFW Alert logs** | Stateful rule matches | Security events, IR | 365 days |
| **NFW Flow logs** | All flows through NFW | Traffic analysis, capacity | 90 days |
| **VPC Flow Logs** | Spoke VPC ENIs | East-west forensics | 90 days |
| **TGW Flow Logs** | TGW attachments | Cross-AZ / cross-account flow | 90 days |

All four are forwarded to a **central security S3 bucket** in a dedicated logging account, with cross-account write permissions and SSE-KMS using a CMK that the workload accounts cannot read.

### Sample detections to build

- Spike in `blocked` actions from a single source IP → potential malware beacon
- DNS queries to newly-registered domains (NRDs) → likely C2
- Outbound to known-bad ASNs → threat intel correlation
- Unusual byte-out volume to allowlisted domains → exfiltration via legitimate SaaS

---

## Failure Modes

| Failure | Blast radius | Detection | Recovery |
|---------|--------------|-----------|----------|
| NFW endpoint unhealthy in AZ-A | All spoke egress through AZ-A | CW alarm on `Healthy` metric | Route 53 / RT failover; degraded but functional |
| TGW attachment fails | One spoke isolated | TGW route propagation alarm | Re-create attachment; ~5 min |
| Suricata rule misfires (DoS) | Legitimate traffic blocked | Spike in `blocked`; user reports | Roll back rule version; alert-only mode for next deploy |
| NAT GW exhaustion (port allocation) | New connections fail | `ErrorPortAllocation` metric | Add second NAT in same AZ; scale out spokes |
| Logging pipeline backed up | Reduced visibility, traffic still flows | CW Logs `IncomingBytes` flatlines | Investigate downstream; firewall fails open for *logging*, not for *enforcement* |

---

## Scaling Considerations

- NFW endpoints scale to **45 Gbps per VPCE** automatically; for higher throughput, use cross-zone load distribution or split into multiple firewalls per traffic class.
- Stateful rule limit: **10,000 rules per policy**. Tiering policies by environment (prod/non-prod) or by traffic class (web/SaaS/admin) keeps this manageable.
- For 100+ spoke VPCs, prefer **AWS Cloud WAN** over plain TGW for policy-as-code network segmentation. The inspection VPC pattern still applies.

---

## Compliance Mapping

| Control | How this design satisfies it |
|---------|------------------------------|
| **PCI-DSS 1.2** — restrict inbound/outbound traffic | Default-deny egress; explicit allowlist |
| **PCI-DSS 1.3** — prohibit direct public access | No IGW in spoke VPCs |
| **PCI-DSS 10.1–10.3** — audit trails | Centralized NFW + Flow Logs with full provenance |
| **ISO 27001 A.13.1.1** — network controls | Documented enforcement; tested rules |
| **ISO 27001 A.13.1.3** — segregation in networks | Spoke isolation via TGW route tables |
| **HIPAA §164.312(e)(1)** — transmission security | TLS-only egress for PHI workloads; inspection where decryptable |
| **NIST 800-53 SC-7** — boundary protection | Single, monitored egress boundary |
| **CIS AWS Foundations 4.x** — networking | Aligned with VPC and security recommendations |
