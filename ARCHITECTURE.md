# Architecture

## Design objective

The design gives private spoke VPCs a controlled outbound path without placing an internet gateway or NAT gateway in each spoke. AWS Network Firewall evaluates traffic before source NAT, retaining the originating private address in firewall telemetry.

## Components

- Two demo spoke VPCs with private and TGW-attachment subnets
- One Transit Gateway with separate spoke and inspection route tables
- One inspection VPC spanning two Availability Zones
- Per-AZ TGW-attachment, firewall, and NAT subnets
- One Network Firewall endpoint and NAT gateway per AZ
- CloudWatch alert and flow log groups encrypted with KMS

The Terraform deploys these resources in one account for learning and validation. A real multi-account implementation normally places the Transit Gateway and inspection VPC in a network account and shares connectivity through AWS RAM or an established landing-zone pattern.

## Forward routing

| Hop | Route decision |
|---|---|
| Spoke private subnet | `0.0.0.0/0 -> TGW` |
| TGW spoke route table | `0.0.0.0/0 -> inspection attachment` |
| Inspection TGW-attachment subnet | `0.0.0.0/0 -> same-AZ firewall endpoint` |
| Inspection firewall subnet | `0.0.0.0/0 -> same-AZ NAT gateway` |
| NAT subnet | `0.0.0.0/0 -> internet gateway` |

## Return routing

| Hop | Route decision |
|---|---|
| Internet gateway/NAT gateway | Reverse translation returns the packet to the NAT subnet path |
| NAT subnet | Each spoke CIDR `-> same-AZ firewall endpoint` |
| Firewall subnet | Each spoke CIDR `-> TGW` |
| TGW inspection route table | Propagated spoke CIDR `-> corresponding spoke attachment` |
| Spoke VPC | Local route to the original workload |

The NAT subnet must not route spoke CIDRs directly to Transit Gateway. That shortcut bypasses stateful return inspection.

## Availability Zone affinity

The spoke sends traffic to Transit Gateway; it does not select a firewall endpoint itself. Transit Gateway appliance mode on the inspection attachment helps maintain flow symmetry. Inside the inspection VPC, separate per-AZ route tables select the firewall endpoint and NAT gateway in the same AZ. Spoke attachments do not require appliance mode.

This design does not implement automated cross-AZ failover. Test the desired failure behavior and cost trade-offs before adding route automation.

## Firewall policy

Stateless rules drop UDP/443 and forward other traffic to the stateful engine. The stateful engine uses strict rule order. `HOME_NET` is explicitly set to all spoke CIDRs because the sources sit outside the firewall VPC.

Managed threat signatures and custom deny rules are evaluated before the generated domain allowlist so an allowlisted destination does not automatically bypass earlier security checks. The allowlist evaluates TLS SNI and HTTP Host. The policy uses established-flow default actions so the engine can observe enough of the session to identify the application-layer hostname. Test this behavior with your provider version and policy set before production use.

## Optional TLS inspection

TLS inspection is off by default. Enabling it requires an appropriate ACM certificate authority, client trust distribution, exception management, and tests for certificate pinning, mutual TLS, certificate rotation, and application compatibility. Domain filtering without decryption and TLS payload inspection are distinct controls.

## Trust boundaries

- Workloads are untrusted traffic sources.
- Transit Gateway is the routing boundary.
- The inspection VPC is a shared security service boundary.
- Firewall policy and logs are security-administration assets.
- The internet is untrusted.

Use separate administrative roles, protected Terraform state, change review, and centralized immutable log retention in a production design.

## Failure considerations

- A firewall endpoint, NAT gateway, route, or TGW attachment failure can remove outbound connectivity.
- A permissive rule can create an egress gap; a restrictive rule can create an outage.
- Log delivery failure reduces visibility but should be monitored separately from enforcement.
- Cross-AZ recovery may introduce asymmetric paths or additional charges.
- Centralization increases blast radius and makes tested change control essential.
