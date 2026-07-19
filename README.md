# AWS Centralized Egress Inspection

A deployable reference architecture for routing outbound traffic from spoke VPCs through AWS Transit Gateway, AWS Network Firewall, and same-AZ NAT gateways.

> This project is a reference implementation, not a claim of production certification. Validate routing, policy behavior, quotas, cost, resilience, and operational controls in your own AWS environment before adoption.

## Why this project exists

Centralized inspection looks simple on an architecture diagram. The difficult part is preserving a symmetric path through a stateful firewall in both directions. A direct NAT-subnet route back to Transit Gateway bypasses the firewall and breaks that security property.

This version implements the complete path:

```text
Forward:
Spoke -> TGW -> TGW attachment subnet -> same-AZ firewall endpoint
      -> firewall subnet -> same-AZ NAT gateway -> IGW -> Internet

Return:
Internet -> IGW -> NAT gateway -> NAT subnet -> same-AZ firewall endpoint
         -> firewall subnet -> TGW -> Spoke
```

## Security controls demonstrated

- Separate Transit Gateway route tables for spoke and inspection attachments
- Appliance mode on the inspection VPC attachment
- Per-AZ firewall, NAT, and TGW-attachment route tables
- Explicit `HOME_NET` containing all spoke CIDRs
- Strict-order stateful policy with application-aware established-flow defaults
- TLS SNI and HTTP Host domain allowlisting
- Stateless blocking of UDP/443 to force compatible clients away from QUIC
- Network Firewall alert and flow logs encrypted with a customer-managed KMS key
- VPC Flow Logs for demo spokes
- Optional TLS inspection, disabled by default

## Architecture

![AWS Network Firewall centralized egress architecture](diagrams/architecture.png)

The route-by-route explanation is available in [`ARCHITECTURE.md`](ARCHITECTURE.md). Additional diagram information is available in [`diagrams/architecture.md`](diagrams/architecture.md).

## Repository map

```text
.
|-- terraform/               Terraform root and reusable modules
|-- policies/                Custom Suricata rules
|-- scripts/                 Deployment and validation helpers
|-- docs/
|   |-- deployment.md
|   |-- validation.md
|   |-- limitations.md
|   |-- troubleshooting.md
|   |-- screenshot-checklist.md
|   `-- adr/                 Architecture decisions
|-- diagrams/                Published and editable diagrams
`-- .github/workflows/       Formatting, validation, and security scans
```

## Prerequisites

- Terraform 1.6 or later
- AWS CLI v2
- An AWS test account with permissions for VPC, Transit Gateway, Network Firewall, IAM, CloudWatch Logs, and KMS
- Two Availability Zones supported by the selected services

This architecture creates hourly and data-processing charges. Review current AWS pricing before deployment.

## Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars for your test environment.
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Read [`docs/deployment.md`](docs/deployment.md) before applying. Do not commit `terraform.tfvars`, state files, credentials, internal domains, or customer identifiers.

The example allowlist intentionally uses narrow hostnames. Avoid broad shared-service suffixes such as `.amazonaws.com` unless every tenant-accessible destination under that suffix is an accepted exfiltration path.

## Validate before describing it as tested

Run and record every test in [`docs/validation.md`](docs/validation.md). At minimum, prove:

1. An allowed HTTPS hostname succeeds.
2. A non-allowlisted hostname is blocked.
3. UDP/443 is blocked.
4. Network Firewall alert and flow logs are populated.
5. Both forward and return route tables point through the same-AZ firewall endpoint.
6. `terraform destroy` completes without orphaned resources.

The repository intentionally contains no invented screenshots, log samples, performance results, or production claims. Add only sanitized evidence from a deployment you personally validated.

## Important limitations

- SNI/Host allowlisting is not full URL filtering or payload inspection.
- AmazonProvidedDNS traffic is not inspected by Network Firewall; use appropriate DNS controls separately.
- Direct-IP access and protocols other than HTTP/TLS need explicit policy decisions.
- Encrypted ClientHello can reduce hostname visibility.
- Blocking UDP/443 affects QUIC and may cause fallback or application failure.
- TLS inspection requires certificate lifecycle management and can break pinned or mutual-TLS applications.
- Centralization increases dependency on Transit Gateway and the inspection VPC.

See [`docs/limitations.md`](docs/limitations.md) for the full discussion.

## Safe cleanup

```bash
cd terraform
terraform plan -destroy
terraform apply -var='enable_firewall_protections=false'
cd ..
TF_VAR_enable_firewall_protections=false ./scripts/destroy.sh
```

Confirm the target AWS account and workspace before approving destruction. The separate apply deliberately disables Network Firewall protection and must be reviewed before running the cleanup script. The script will not disable protection automatically.

## Contributing and security

Contributions are welcome through pull requests. See [`CONTRIBUTING.md`](CONTRIBUTING.md). Report security concerns according to [`SECURITY.md`](SECURITY.md).

## License

MIT. See [`LICENSE`](LICENSE).
